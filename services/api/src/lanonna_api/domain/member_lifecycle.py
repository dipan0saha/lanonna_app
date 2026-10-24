from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.membership import require_owner_baby
from lanonna_activity_copy import ActivityEventType
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.db import get_connection
from lanonna_api.repositories.memberships import (
    OwnLeaveOutcome,
    count_active_owners,
    get_active_membership,
    list_baby_members,
    lock_baby_profile_for_update,
    lock_membership_for_user_for_update,
    soft_remove_membership,
    soft_remove_own_membership,
)


def can_leave_baby(role: str, owner_count: int) -> bool:
    if role == "follower":
        return True
    if role == "owner":
        return owner_count > 1
    return False


def _can_remove_target(
    actor_uid: str,
    target_uid: str,
    target_role: str,
    owner_count: int,
) -> bool:
    if actor_uid == target_uid:
        return False
    if target_role == "owner" and owner_count <= 1:
        return False
    return True


def list_members_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    limit: int,
    offset: int,
) -> list[dict[str, Any]]:
    require_owner_baby(firebase_uid, baby_profile_id)
    owner_count = count_active_owners(baby_profile_id)
    members = list_baby_members(baby_profile_id, limit=limit, offset=offset)
    for row in members:
        row["can_remove"] = _can_remove_target(
            firebase_uid,
            row["firebase_uid"],
            row["role"],
            owner_count,
        )
    return members


def remove_member(
    actor_uid: str,
    baby_profile_id: uuid.UUID,
    target_uid: str,
) -> None:
    require_owner_baby(actor_uid, baby_profile_id)
    if actor_uid == target_uid:
        raise MemberLifecycleError(
            ErrorCode.USE_LEAVE_ENDPOINT,
            "Use leave profile to remove yourself from this baby.",
        )
    target = get_active_membership(baby_profile_id, target_uid)
    if target is None:
        raise MemberLifecycleError(
            ErrorCode.TARGET_NOT_MEMBER,
            "That person is not a member of this baby profile.",
        )
    if target["role"] == "owner":
        owner_count = count_active_owners(baby_profile_id)
        if owner_count <= 1:
            raise MemberLifecycleError(
                ErrorCode.LAST_OWNER,
                "Cannot remove the last owner of this baby profile.",
            )
    with get_connection() as conn:
        if lock_baby_profile_for_update(baby_profile_id, conn) is None:
            raise MemberLifecycleError(
                ErrorCode.NOT_MEMBER,
                "This baby profile no longer exists.",
            )
        locked_target = lock_membership_for_user_for_update(
            baby_profile_id, target_uid, conn
        )
        if locked_target is None:
            raise MemberLifecycleError(
                ErrorCode.TARGET_NOT_MEMBER,
                "That person is not a member of this baby profile.",
            )
        if locked_target["role"] == "owner" and count_active_owners(
            baby_profile_id, conn
        ) <= 1:
            raise MemberLifecycleError(
                ErrorCode.LAST_OWNER,
                "Cannot remove the last owner of this baby profile.",
            )
        if not soft_remove_membership(baby_profile_id, target_uid, conn=conn):
            raise MemberLifecycleError(
                ErrorCode.TARGET_NOT_MEMBER,
                "That person is not a member of this baby profile.",
            )
        insert_activity_event(
            baby_profile_id,
            actor_uid,
            ActivityEventType.MEMBER_REMOVED,
            payload={"target_firebase_uid": target_uid},
            conn=conn,
            row_lock_held=True,
        )


def leave_baby_profile(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    with get_connection() as conn:
        outcome = soft_remove_own_membership(
            baby_profile_id, firebase_uid, conn=conn
        )
        if outcome is OwnLeaveOutcome.NOT_MEMBER:
            raise MemberLifecycleError(
                ErrorCode.NOT_MEMBER,
                "You are not a member of this baby profile.",
            )
        if outcome is OwnLeaveOutcome.SOLE_OWNER:
            raise MemberLifecycleError(
                ErrorCode.SOLE_OWNER_CANNOT_LEAVE,
                "You are the only owner. Add a co-owner and leave, delete the baby "
                "profile, or delete your account.",
            )
        insert_activity_event(
            baby_profile_id,
            firebase_uid,
            ActivityEventType.MEMBER_LEFT,
            conn=conn,
            row_lock_held=True,
        )
