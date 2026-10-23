import uuid
from unittest.mock import patch


from lanonna_api.domain.baby_update import update_baby_profile
from lanonna_api.domain.member_errors import MemberLifecycleError


def _run(*, ended: bool = False, owner_row=None, updated=None):
    with (
        patch("lanonna_api.domain.membership.membership_access_ended", return_value=ended),
        patch("lanonna_api.domain.membership.get_baby_for_owner", return_value=owner_row),
        patch(
            "lanonna_api.domain.baby_update.update_baby_for_owner",
            return_value=updated,
        ) as update,
    ):
        try:
            return update_baby_profile("uid-1", uuid.uuid4(), {"name": "Rowan"}), update
        except Exception as exc:  # noqa: BLE001 - returned for assertions
            return exc, update


def test_owner_update_returns_row():
    row = {"id": "b1", "name": "Rowan"}
    result, update = _run(owner_row={"id": "b1"}, updated=row)
    assert result == row
    assert update.call_args.args[2] == {"name": "Rowan"}


def test_follower_is_forbidden_and_nothing_is_written():
    result, update = _run(owner_row=None)
    assert isinstance(result, PermissionError)
    update.assert_not_called()


def test_ended_membership_raises_membership_ended():
    result, update = _run(ended=True)
    assert isinstance(result, MemberLifecycleError)
    update.assert_not_called()


def test_update_matching_no_owner_row_is_forbidden_not_404():
    result, _ = _run(owner_row={"id": "b1"}, updated=None)
    assert isinstance(result, PermissionError)
