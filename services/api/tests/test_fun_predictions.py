import uuid
from datetime import date
from unittest.mock import patch

import pytest

from lanonna_api.domain.birthdate_vote_window import birthdate_vote_bounds
from lanonna_api.domain.fun import get_predictions, set_birthdate_vote, set_gender_vote
from lanonna_api.domain.fun_closed import PredictionsClosedError

_BABY = uuid.uuid4()


def test_set_gender_vote_always_identified():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.upsert_gender_vote"
    ) as upsert, patch("lanonna_api.domain.fun.insert_activity_event"):
        set_gender_vote("uid1", _BABY, "male")
        upsert.assert_called_once_with(_BABY, "uid1", "male", False)


def test_set_birthdate_vote_always_identified():
    d = date(2026, 10, 15)
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch(
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
    assert payload["predictions_closed"] is False


def test_get_predictions_filters_out_of_range_histogram_rows():
    due = date(2027, 1, 15)
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={
            "role": "follower",
            "lifecycle_status": "expecting",
            "expected_birth_date": due,
        },
    ), patch(
        "lanonna_api.domain.fun.gender_vote_totals",
        return_value={"male": 0, "female": 0},
    ), patch(
        "lanonna_api.domain.fun.get_caller_votes",
        return_value={},
    ), patch(
        "lanonna_api.domain.fun.list_gender_voters",
        return_value=[],
    ), patch(
        "lanonna_api.domain.fun.birthdate_vote_histogram",
        return_value=[
            {"predicted_birth_date": date(2027, 1, 14), "count": 1},
            {"predicted_birth_date": date(2099, 12, 31), "count": 1},
        ],
    ):
        payload = get_predictions("uid1", _BABY)

    vote_min, vote_max = birthdate_vote_bounds(due)
    assert payload["birthdate_vote_min"] == vote_min.isoformat()
    assert payload["birthdate_vote_max"] == vote_max.isoformat()
    assert payload["birthdate_histogram"] == [{"date": "2027-01-14", "count": 1}]


def test_get_predictions_closed_when_baby_is_born():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={
            "role": "follower",
            "lifecycle_status": "born",
            "expected_birth_date": date(2026, 8, 1),
        },
    ), patch(
        "lanonna_api.domain.fun.gender_vote_totals",
        return_value={"male": 1, "female": 2},
    ), patch(
        "lanonna_api.domain.fun.get_caller_votes",
        return_value={"gender": "female", "birthdate": date(2026, 8, 1)},
    ), patch(
        "lanonna_api.domain.fun.list_gender_voters",
        return_value=[],
    ), patch(
        "lanonna_api.domain.fun.birthdate_vote_histogram",
        return_value=[{"predicted_birth_date": date(2026, 8, 1), "count": 1}],
    ):
        payload = get_predictions("uid1", _BABY)

    assert payload["predictions_closed"] is True
    assert payload["gender_totals"] == {"male": 1, "female": 2}
    assert payload["viewer_gender_vote"] == "female"
    assert payload["viewer_birthdate_vote"] == "2026-08-01"
    assert payload["birthdate_histogram"] == [{"date": "2026-08-01", "count": 1}]


def test_set_gender_vote_rejected_when_baby_is_born():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner", "lifecycle_status": "born"},
    ), patch(
        "lanonna_api.domain.fun.upsert_gender_vote"
    ) as upsert, patch(
        "lanonna_api.domain.fun.insert_activity_event"
    ) as activity:
        with pytest.raises(PredictionsClosedError) as exc:
            set_gender_vote("uid1", _BABY, "female")
    upsert.assert_not_called()
    activity.assert_not_called()
    assert exc.value.code == "predictions_closed"


def test_set_birthdate_vote_rejected_when_baby_is_born():
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower", "lifecycle_status": "born"},
    ), patch(
        "lanonna_api.domain.fun.upsert_birthdate_vote"
    ) as upsert:
        with pytest.raises(PredictionsClosedError):
            set_birthdate_vote("uid1", _BABY, date(2026, 9, 1))
    upsert.assert_not_called()
