from __future__ import annotations

import uuid

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.repositories.memberships import (
    membership_access_ended,
    owner_membership_exists,
)


def _raise_if_membership_ended(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    if membership_access_ended(baby_profile_id, firebase_uid):
        raise MemberLifecycleError(
            ErrorCode.MEMBERSHIP_ENDED,
            "You no longer have access to this baby profile.",
        )


def assert_owner_membership(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    _raise_if_membership_ended(firebase_uid, baby_profile_id)
    if not owner_membership_exists(firebase_uid, baby_profile_id):
        raise PermissionError("Owner membership required for this baby profile.")


def require_owner_baby(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict:
    """Owner check via baby row (includes profile fields).

    Non-owners (including active followers) raise ``PermissionError`` → HTTP **403**
    via ``map_domain_errors``. Use at the start of owner-only baby routes (e.g.
    ``PATCH`` / ``DELETE`` ``/v1/babies/{id}``) instead of inferring forbidden
    access from an empty SQL ``RETURNING`` row (which produced **404** on PATCH).
    """
    _raise_if_membership_ended(firebase_uid, baby_profile_id)
    baby = get_baby_for_owner(firebase_uid, baby_profile_id)
    if baby is None:
        raise PermissionError("Owner access required")
    return baby
