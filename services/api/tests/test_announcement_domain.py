from datetime import date, timedelta
from unittest.mock import patch
import uuid

import pytest

from lanonna_api.domain.announcement import patch_announcement
from lanonna_api.domain.announcement_validation import (
    validate_announcement_birth_time,
    validate_announcement_fields,
)
from lanonna_api.domain.home import _utc_today


def test_validate_announcement_birth_time_rejects_garbage():
    with pytest.raises(ValueError, match="HH:MM"):
        validate_announcement_birth_time("25:99")


def test_validate_announcement_fields_rejects_future_birth_date():
    future = _utc_today() + timedelta(days=30)
    with pytest.raises(ValueError, match="future"):
        validate_announcement_fields(birth_date=future)


@patch("lanonna_api.domain.announcement.upsert_announcement")
@patch("lanonna_api.domain.announcement.list_comments", return_value=[])
@patch("lanonna_api.domain.announcement.get_announcement")
@patch("lanonna_api.domain.announcement.assert_owner_membership")
def test_patch_announcement_preserves_unset_fields(
    _owner,
    mock_get,
    _list_comments,
    mock_upsert,
):
    baby_id = uuid.uuid4()
    mock_get.return_value = {
        "baby_profile_id": baby_id,
        "first_name": "Baby",
        "last_name": "Smith",
        "gender": "female",
        "birth_date": date(2026, 1, 15),
        "birth_time": "14:30",
        "weight_text": "7 lb",
        "length_text": None,
        "photo_id": None,
    }
    mock_upsert.return_value = {
        "id": uuid.uuid4(),
        "baby_profile_id": baby_id,
        "first_name": "Baby",
        "last_name": "Smith",
        "gender": "female",
        "birth_date": date(2026, 1, 15),
        "birth_time": "14:30",
        "weight_text": "8 lb",
        "length_text": None,
        "photo_id": None,
        "squish_count": 0,
        "comment_count": 0,
    }

    patch_announcement("owner", baby_id, {"weight_text": "8 lb"})

    kwargs = mock_upsert.call_args.kwargs
    assert kwargs["first_name"] == "Baby"
    assert kwargs["weight_text"] == "8 lb"
