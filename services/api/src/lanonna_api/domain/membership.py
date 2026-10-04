from __future__ import annotations

import uuid

from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.repositories.memberships import owner_membership_exists


def assert_owner_membership(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    if not owner_membership_exists(firebase_uid, baby_profile_id):
        raise PermissionError("Owner membership required for this baby profile.")


def require_owner_baby(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict:
    """Owner check via baby row (includes profile fields). Raises PermissionError if not owner."""
    baby = get_baby_for_owner(firebase_uid, baby_profile_id)
    if baby is None:
        raise PermissionError("Owner access required")
    return baby
