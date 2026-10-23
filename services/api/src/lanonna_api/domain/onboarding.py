from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import Any

from lanonna_api.domain.date_validation import utc_today
from lanonna_api.domain.errors import ErrorCode, InvalidInputError
from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.domain.name_suggestions import (
    normalize_gender_for_first_moment_seed,
    normalize_suggested_name,
)
from lanonna_api.first_moment_presets import (
    event_preset,
    event_starts_at_born,
    event_starts_at_expecting,
    registry_preset,
)
from lanonna_api.repositories.first_moment import (
    insert_seed_event,
    insert_seed_name_suggestion,
    insert_seed_registry_item,
)
from lanonna_api.repositories.users import (
    complete_owner_onboarding,
    get_app_user,
    self_created_owner_baby_profile_id,
    user_has_baby_membership,
    user_has_follower_membership,
    user_has_owner_baby,
    user_has_self_created_baby,
)


def _first_moment_event_starts_at(baby: dict[str, Any], day_offset: int) -> datetime:
    """Start of a seeded first-moment event (#403).

    Born babies count forward from the birth date (clamped to today). Otherwise
    the anchor is the due date (or 90 days out when unknown), expecting offsets
    count back from it, and dates are clamped to no earlier than the UTC day.
    """
    lifecycle = baby.get("lifecycle_status") or "expecting"
    actual = baby.get("actual_birth_date")
    if lifecycle == "born" and actual is not None:
        return event_starts_at_born(actual, day_offset)
    due = baby.get("expected_birth_date") or utc_today() + timedelta(days=90)
    return event_starts_at_expecting(due, day_offset)


def seed_expecting_profile_name_suggestions(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    name_suggestions: list[dict[str, str]],
    *,
    baby: dict[str, Any] | None = None,
) -> int:
    """Insert Fun name votes from expecting baby profile name fields (deduped by name)."""
    profile = baby if baby is not None else require_owner_baby(firebase_uid, baby_profile_id)
    if (profile.get("lifecycle_status") or "expecting") != "expecting":
        return 0
    seen: set[str] = set()
    created = 0
    for row in name_suggestions:
        name = normalize_suggested_name(row.get("name") or "")
        if not name:
            continue
        key = name.casefold()
        if key in seen:
            continue
        seen.add(key)
        gender = normalize_gender_for_first_moment_seed(row.get("gender") or "unknown")
        insert_seed_name_suggestion(baby_profile_id, firebase_uid, name, gender)
        created += 1
    return created


def onboarding_status_for_user(
    firebase_uid: str,
    *,
    email_verified: bool,
) -> dict[str, Any]:
    """Owner-onboarding gate (#31).

    ``needs_owner_onboarding`` is true only when the user has an active owner
    membership they created (``baby_memberships.joined_via = 'created'``) and
    has not finished owner onboarding. An invited co-owner
    (``joined_via = 'invite'``) is not sent through owner onboarding.

    ``can_access_main_app`` is true when the profile is complete and any of:
    owner onboarding is finished, the user has an active follower membership,
    or the user has an active owner membership that is not a self-created baby.
    ``has_owner_baby`` remains "any active owner role" and is not itself a
    reason to block the main app.
    """
    row = get_app_user(firebase_uid)
    if row is None:
        raise LookupError("User not found")
    display_name = row.get("display_name")
    terms_at = row.get("terms_accepted_at")
    profile_complete = bool(
        display_name and str(display_name).strip() and terms_at is not None
    )
    has_owner_baby = user_has_owner_baby(firebase_uid)
    has_baby_membership = user_has_baby_membership(firebase_uid)
    has_self_created_baby = user_has_self_created_baby(firebase_uid)
    has_follower_membership = user_has_follower_membership(firebase_uid)
    owner_onboarding_completed = row.get("owner_onboarding_completed_at") is not None
    needs_owner_onboarding = (
        not owner_onboarding_completed and has_self_created_baby
    )
    can_access_main_app = profile_complete and (
        owner_onboarding_completed
        or has_follower_membership
        or (has_owner_baby and not has_self_created_baby)
    )
    owner_baby_id = self_created_owner_baby_profile_id(firebase_uid)
    return {
        "email_verified": email_verified,
        "profile_complete": profile_complete,
        "has_owner_baby": has_owner_baby,
        "has_baby_membership": has_baby_membership,
        "owner_onboarding_completed": owner_onboarding_completed,
        "needs_owner_onboarding": needs_owner_onboarding,
        "can_access_main_app": can_access_main_app,
        "owner_onboarding_baby_profile_id": owner_baby_id,
    }


def complete_owner_onboarding_for_user(
    firebase_uid: str,
    *,
    email_verified: bool,
) -> dict[str, Any]:
    row = get_app_user(firebase_uid)
    if row is None:
        raise LookupError("User not found")
    if not row.get("display_name"):
        raise InvalidInputError(ErrorCode.PROFILE_INCOMPLETE, "Complete your profile before finishing onboarding.")
    if not user_has_self_created_baby(firebase_uid):
        raise InvalidInputError(ErrorCode.BABY_PROFILE_REQUIRED, "Create a baby profile before finishing onboarding.")
    if not email_verified:
        raise InvalidInputError(ErrorCode.EMAIL_NOT_VERIFIED, "Verify your email before finishing onboarding.")
    complete_owner_onboarding(firebase_uid)
    return onboarding_status_for_user(
        firebase_uid,
        email_verified=email_verified,
    )


def seed_first_moment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_preset_ids: list[str],
    registry_preset_ids: list[str],
    name_suggestions: list[dict[str, str]],
) -> dict[str, int]:
    baby = require_owner_baby(firebase_uid, baby_profile_id)
    events_created = 0
    registry_created = 0
    names_created = 0

    for preset_id in event_preset_ids:
        preset = event_preset(preset_id)
        if preset is None:
            continue
        insert_seed_event(
            baby_profile_id,
            firebase_uid,
            preset.label,
            _first_moment_event_starts_at(baby, preset.day_offset),
            catalog_suggestion_id=preset.id,
        )
        events_created += 1

    for preset_id in registry_preset_ids:
        preset = registry_preset(preset_id)
        if preset is None:
            continue
        insert_seed_registry_item(
            baby_profile_id,
            firebase_uid,
            preset.label,
            catalog_suggestion_id=preset.resolved_catalog_suggestion_id(),
        )
        registry_created += 1

    names_created += seed_expecting_profile_name_suggestions(
        firebase_uid,
        baby_profile_id,
        name_suggestions,
        baby=baby,
    )

    return {
        "events_created": events_created,
        "registry_items_created": registry_created,
        "name_suggestions_created": names_created,
    }
