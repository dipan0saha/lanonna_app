from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.domain.users_display import actor_display_name
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.repositories.memberships import (
    count_active_owners,
    get_active_membership,
    list_baby_members,
    soft_remove_membership,
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
) -> list[dict[str, Any]]:
    require_owner_baby(firebase_uid, baby_profile_id)
    owner_count = count_active_owners(baby_profile_id)
    members = list_baby_members(baby_profile_id)
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
            "use_leave_endpoint",
            "Use leave profile to remove yourself from this baby.",
        )
    target = get_active_membership(baby_profile_id, target_uid)
    if target is None:
        raise MemberLifecycleError(
            "target_not_member",
            "That person is not a member of this baby profile.",
        )
    if target["role"] == "owner":
        owner_count = count_active_owners(baby_profile_id)
        if owner_count <= 1:
            raise MemberLifecycleError(
                "last_owner",
                "Cannot remove the last owner of this baby profile.",
            )
    target_name = target.get("display_name") or "Family member"
    if not soft_remove_membership(baby_profile_id, target_uid):
        raise MemberLifecycleError(
            "target_not_member",
            "That person is not a member of this baby profile.",
        )
    actor_name = actor_display_name(actor_uid)
    insert_activity_event(
        baby_profile_id,
        actor_uid,
        "member_removed",
        f"{actor_name} removed {target_name} from the family",
        {"target_firebase_uid": target_uid},
    )


def leave_baby_profile(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    membership = get_active_membership(baby_profile_id, firebase_uid)
    if membership is None:
        raise MemberLifecycleError(
            "not_member",
            "You are not a member of this baby profile.",
        )
    if membership["role"] == "owner" and count_active_owners(baby_profile_id) <= 1:
        raise MemberLifecycleError(
            "sole_owner_cannot_leave",
            "You are the only owner. Add a co-owner, delete the baby profile, "
            "or delete your account to leave.",
        )
    if not soft_remove_membership(baby_profile_id, firebase_uid):
        raise MemberLifecycleError(
            "not_member",
            "You are not a member of this baby profile.",
        )
    actor_name = actor_display_name(firebase_uid)
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        "member_left",
        f"{actor_name} left the family",
        None,
    )
