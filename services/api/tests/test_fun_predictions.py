import uuid
from datetime import date
from unittest.mock import patch

from lanonna_api.domain.fun import get_predictions, set_birthdate_vote, set_gender_vote

_BABY = uuid.uuid4()


def test_set_gender_vote_always_identified():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch("lanonna_api.domain.fun.upsert_app_user"), patch(
        "lanonna_api.domain.fun.upsert_gender_vote"
    ) as upsert, patch("lanonna_api.domain.fun.insert_activity_event"):
        set_gender_vote("uid1", _BABY, "male")
        upsert.assert_called_once_with(_BABY, "uid1", "male", False)


def test_set_birthdate_vote_always_identified():
    d = date(2026, 10, 15)
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch("lanonna_api.domain.fun.upsert_app_user"), patch(
        "lanonna_api.domain.fun.upsert_birthdate_vote"
    ) as upsert:
        set_birthdate_vote("uid1", _BABY, d)
        upsert.assert_called_once_with(_BABY, "uid1", d, False)


def test_get_predictions_masks_legacy_anonymous_voters():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.gender_vote_totals",
        return_value={"male": 2, "female": 0},
    ), patch(
        "lanonna_api.domain.fun.get_caller_votes",
        return_value={"gender": "male"},
    ), patch(
        "lanonna_api.domain.fun.list_gender_voters",
        return_value=[
            {
                "gender_value": "male",
                "is_anonymous": True,
                "display_name": "Hidden User",
                "email": "h@example.com",
            },
            {
                "gender_value": "male",
                "is_anonymous": False,
                "display_name": "Visible User",
                "email": "v@example.com",
            },
        ],
    ), patch(
        "lanonna_api.domain.fun.birthdate_vote_histogram",
        return_value=[],
    ):
        payload = get_predictions("uid1", _BABY)

    assert "is_anonymous" not in payload
    names = [v["display_name"] for v in payload["gender_voters"]]
    assert names == ["Anonymous", "Visible User"]
    assert all("is_anonymous" not in v for v in payload["gender_voters"])
