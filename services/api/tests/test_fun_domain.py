import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.fun import list_names, suggest_name, toggle_like
from lanonna_api.repositories.child_write_locks import ChildWriteParent


def test_follower_name_limit_per_gender():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.find_name_suggestion_case_insensitive",
        return_value=None,
    ), patch(
        "lanonna_api.domain.fun.get_connection",
    ) as get_conn, patch(
        "lanonna_api.domain.fun.ensure_baby_profile_for_child_write",
    ), patch(
        "lanonna_api.domain.fun.lock_membership_for_user_for_update",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.count_suggestions_by_author_gender",
        return_value=1,
    ):
        get_conn.return_value.__enter__.return_value = object()
        with pytest.raises(PermissionError):
            suggest_name("uid", baby_id, "Alex", "male")


def test_suggest_name_rejects_case_insensitive_duplicate():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.fun.find_name_suggestion_case_insensitive",
        return_value={"id": uuid.uuid4(), "suggested_name": "James", "gender": "male"},
    ):
        with pytest.raises(ValueError, match="already on the list"):
            suggest_name("uid", baby_id, "james", "male")


def test_list_names_does_not_call_user_has_like_per_row():
    baby_id = uuid.uuid4()
    sid = uuid.uuid4()
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.fun.list_caller_likes",
        return_value=[{"gender": "female", "name_suggestion_id": sid}],
    ), patch(
        "lanonna_api.domain.fun.list_name_suggestions",
        return_value=[
            {
                "id": sid,
                "suggested_name": "Ava",
                "gender": "female",
                "like_count": 0,
                "suggested_by_firebase_uid": "other",
                "author_display_name": "Other",
            }
        ],
    ), patch(
        "lanonna_api.domain.fun.user_has_like",
    ) as has_like_mock:
        result = list_names("uid", baby_id)
    has_like_mock.assert_not_called()
    assert result["suggestions"][0]["viewer_has_liked"] is True


def test_toggle_like_runs_in_single_connection():
    baby_id = uuid.uuid4()
    sid = uuid.uuid4()
    conn = object()
    cm = patch(
        "lanonna_api.domain.fun.get_connection",
    )
    with patch(
        "lanonna_api.domain.fun.require_membership",
    ), patch(
        "lanonna_api.domain.fun.get_name_suggestion",
        return_value={"id": sid, "gender": "male"},
    ), patch(
        "lanonna_api.domain.fun.user_has_like",
        return_value=False,
    ) as has_like_mock, patch(
        "lanonna_api.domain.fun.remove_likes_for_user_gender",
    ) as remove_gender_mock, patch(
        "lanonna_api.domain.fun.add_like",
    ) as add_like_mock, patch(
        "lanonna_api.domain.fun.ensure_parent_row_for_child_write",
    ) as lock_parent_mock, cm as get_conn_mock:
        get_conn_mock.return_value.__enter__.return_value = conn
        out = toggle_like("uid", baby_id, sid)
    assert out == {"liked": True}
    lock_parent_mock.assert_called_once_with(
        ChildWriteParent.NAME_SUGGESTIONS, sid, conn
    )
    has_like_mock.assert_called_once_with(sid, "uid", conn)
    remove_gender_mock.assert_called_once_with(baby_id, "uid", "male", conn)
    add_like_mock.assert_called_once_with(sid, "uid", conn)
