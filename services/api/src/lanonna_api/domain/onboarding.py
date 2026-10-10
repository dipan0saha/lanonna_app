from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Any

from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.domain.name_suggestions import (
    normalize_gender_for_first_moment_seed,
    normalize_suggested_name,
)
from lanonna_api.first_moment_presets import (
    event_preset,
    event_starts_at,
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
    user_has_baby_membership,
    user_has_follower_membership,
    user_has_owner_baby,
    user_has_self_created_baby,
)


def _anchor_date(baby: dict[str, Any]) -> date:
    lifecycle = baby.get("lifecycle_status") or "expecting"
    if lifecycle == "born":
        actual = baby.get("actual_birth_date")
        if actual is not None:
            return actual
    expected = baby.get("expected_birth_date")
    if expected is not None:
        return expected
    return date.today() + timedelta(days=90)


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
    return {
        "email_verified": email_verified,
        "profile_complete": profile_complete,
        "has_owner_baby": has_owner_baby,
        "has_baby_membership": has_baby_membership,
        "owner_onboarding_completed": owner_onboarding_completed,
        "needs_owner_onboarding": needs_owner_onboarding,
        "can_access_main_app": can_access_main_app,
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
        raise ValueError("Complete your profile before finishing onboarding.")
    if not user_has_self_created_baby(firebase_uid):
        raise ValueError("Create a baby profile before finishing onboarding.")
    if not email_verified:
        raise ValueError("Verify your email before finishing onboarding.")
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
    anchor = _anchor_date(baby)
    events_created = 0
    registry_created = 0
    names_created = 0

    for preset_id in event_preset_ids:
        preset = event_preset(preset_id)
        if preset is None:
            continue
        starts = event_starts_at(anchor, preset.day_offset)
        insert_seed_event(baby_profile_id, firebase_uid, preset.label, starts)
        events_created += 1

    for preset_id in registry_preset_ids:
        preset = registry_preset(preset_id)
        if preset is None:
            continue
        insert_seed_registry_item(baby_profile_id, firebase_uid, preset.label)
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
