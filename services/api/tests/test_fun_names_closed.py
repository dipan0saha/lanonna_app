import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.fun import remove_suggestion, suggest_name, toggle_like
from lanonna_api.domain.fun_closed import FunClosedError

_BABY = uuid.uuid4()
_SID = uuid.uuid4()


def test_suggest_name_rejected_when_baby_is_born():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner", "lifecycle_status": "born"},
    ), patch("lanonna_api.domain.fun.insert_name_suggestion") as insert:
        with pytest.raises(FunClosedError) as exc:
            suggest_name("uid1", _BABY, "Milo", "male")
    insert.assert_not_called()
    assert exc.value.code == "fun_closed"


def test_toggle_like_rejected_when_baby_is_born():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower", "lifecycle_status": "born"},
    ), patch(
        "lanonna_api.domain.fun.get_name_suggestion",
        return_value={"id": _SID, "gender": "male"},
    ), patch("lanonna_api.domain.fun.user_has_like", return_value=False):
        with pytest.raises(FunClosedError):
            toggle_like("uid1", _BABY, _SID)


def test_remove_suggestion_rejected_when_baby_is_born():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner", "lifecycle_status": "born"},
    ), patch("lanonna_api.domain.fun.get_name_suggestion") as get_row:
        with pytest.raises(FunClosedError):
            remove_suggestion("uid1", _BABY, _SID)
    get_row.assert_not_called()
