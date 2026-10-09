import uuid
from unittest.mock import patch

from lanonna_api.domain.fun import list_names

_BABY = uuid.uuid4()
_SID_OWN = uuid.uuid4()
_SID_OTHER = uuid.uuid4()


def _suggestion_row(sid: uuid.UUID, author_uid: str, name: str = "Test") -> dict:
    return {
        "id": sid,
        "suggested_name": name,
        "gender": "male",
        "like_count": 0,
        "suggested_by_firebase_uid": author_uid,
        "display_name": "Author",
        "email": "a@example.com",
    }


def test_list_names_can_delete_for_owner_on_all_rows():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.fun.get_baby_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.fun.caller_liked_suggestion_ids",
        return_value={"male": None, "female": None},
    ), patch(
        "lanonna_api.domain.fun.list_name_suggestions",
        return_value=[
            _suggestion_row(_SID_OWN, "owner-uid"),
            _suggestion_row(_SID_OTHER, "follower-uid"),
        ],
    ), patch("lanonna_api.domain.fun.user_has_like", return_value=False):
        payload = list_names("owner-uid", _BABY)

    flags = {s["id"]: s["can_delete"] for s in payload["suggestions"]}
    assert flags[str(_SID_OWN)] is True
    assert flags[str(_SID_OTHER)] is True


def test_list_names_can_delete_for_follower_only_own_row():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.get_baby_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.caller_liked_suggestion_ids",
        return_value={"male": None, "female": None},
    ), patch(
        "lanonna_api.domain.fun.list_name_suggestions",
        return_value=[
            _suggestion_row(_SID_OWN, "follower-uid", "Mine"),
            _suggestion_row(_SID_OTHER, "other-uid", "Theirs"),
        ],
    ), patch("lanonna_api.domain.fun.user_has_like", return_value=False):
        payload = list_names("follower-uid", _BABY)

    by_id = {s["id"]: s for s in payload["suggestions"]}
    assert by_id[str(_SID_OWN)]["can_delete"] is True
    assert by_id[str(_SID_OWN)]["is_mine"] is True
    assert by_id[str(_SID_OTHER)]["can_delete"] is False
    assert by_id[str(_SID_OTHER)]["is_mine"] is False
