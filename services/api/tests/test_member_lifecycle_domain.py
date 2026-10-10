import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.member_lifecycle import (
    leave_baby_profile,
    list_members_for_owner,
    remove_member,
)


def test_list_members_sets_can_remove_for_follower_not_self():
    baby_id = uuid.uuid4()
    members = [
        {
            "firebase_uid": "owner-1",
            "role": "owner",
            "display_name": "Owner",
            "created_at": "2026-01-01",
        },
        {
            "firebase_uid": "follower-1",
            "role": "follower",
            "display_name": "Follower",
            "created_at": "2026-01-02",
        },
    ]
    with (
        patch(
            "lanonna_api.domain.member_lifecycle.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.count_active_owners",
            return_value=1,
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.list_baby_members",
            return_value=members,
        ),
    ):
        result = list_members_for_owner("owner-1", baby_id)
    assert result[0]["can_remove"] is False
    assert result[1]["can_remove"] is True


def test_remove_member_rejects_self():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.member_lifecycle.require_owner_baby",
        return_value={"id": baby_id},
    ):
        with pytest.raises(MemberLifecycleError) as exc:
            remove_member("owner-1", baby_id, "owner-1")
    assert exc.value.code == "use_leave_endpoint"


def test_remove_member_last_owner_blocked():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.member_lifecycle.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.get_active_membership",
            return_value={
                "firebase_uid": "owner-2",
                "role": "owner",
                "display_name": "Co",
            },
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.count_active_owners",
            return_value=1,
        ),
    ):
        with pytest.raises(MemberLifecycleError) as exc:
            remove_member("owner-1", baby_id, "owner-2")
    assert exc.value.code == "last_owner"


def test_remove_follower_records_activity():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.member_lifecycle.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.get_active_membership",
            return_value={
                "firebase_uid": "follower-1",
                "role": "follower",
                "display_name": "Alex",
            },
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.soft_remove_membership",
            return_value=True,
        ) as soft_remove,
        patch("lanonna_api.domain.member_lifecycle.actor_display_name", return_value="Owner"),
        patch(
            "lanonna_api.domain.member_lifecycle.insert_activity_event",
        ) as activity,
    ):
        remove_member("owner-1", baby_id, "follower-1")
    soft_remove.assert_called_once_with(baby_id, "follower-1")
    activity.assert_called_once()
    assert activity.call_args[0][2] == "member_removed"


def test_leave_sole_owner_blocked():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.member_lifecycle.get_active_membership",
            return_value={"role": "owner", "display_name": "Owner"},
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.count_active_owners",
            return_value=1,
        ),
    ):
        with pytest.raises(MemberLifecycleError) as exc:
            leave_baby_profile("owner-1", baby_id)
    assert exc.value.code == "sole_owner_cannot_leave"


def test_leave_follower_succeeds():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.member_lifecycle.get_active_membership",
            return_value={"role": "follower", "display_name": "Fan"},
        ),
        patch(
            "lanonna_api.domain.member_lifecycle.soft_remove_membership",
            return_value=True,
        ),
        patch("lanonna_api.domain.member_lifecycle.actor_display_name", return_value="Fan"),
        patch("lanonna_api.domain.member_lifecycle.insert_activity_event"),
    ):
        leave_baby_profile("follower-1", baby_id)
