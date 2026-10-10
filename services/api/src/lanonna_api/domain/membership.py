from __future__ import annotations

import uuid

from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.repositories.memberships import (
    has_removed_membership,
    owner_membership_exists,
)


def _raise_if_membership_ended(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    if has_removed_membership(baby_profile_id, firebase_uid):
        raise MemberLifecycleError(
            "membership_ended",
            "You no longer have access to this baby profile.",
        )


def assert_owner_membership(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    _raise_if_membership_ended(firebase_uid, baby_profile_id)
    if not owner_membership_exists(firebase_uid, baby_profile_id):
        raise PermissionError("Owner membership required for this baby profile.")


def require_owner_baby(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict:
    """Owner check via baby row (includes profile fields). Raises PermissionError if not owner."""
    _raise_if_membership_ended(firebase_uid, baby_profile_id)
    baby = get_baby_for_owner(firebase_uid, baby_profile_id)
    if baby is None:
        raise PermissionError("Owner access required")
    return baby
