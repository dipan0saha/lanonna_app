import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest

from lanonna_api.domain.calendar import _parse_month, create_calendar_event


def test_parse_month_january():
    start, end = _parse_month("2026-01")
    assert start == datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert end == datetime(2026, 2, 1, tzinfo=timezone.utc)


def test_parse_month_december():
    start, end = _parse_month("2025-12")
    assert start == datetime(2025, 12, 1, tzinfo=timezone.utc)
    assert end == datetime(2026, 1, 1, tzinfo=timezone.utc)


def test_create_event_rejects_duplicate_catalog_suggestion():
    baby_id = uuid.uuid4()
    starts = datetime(2026, 6, 1, 12, 0, tzinfo=timezone.utc)
    with patch(
        "lanonna_api.domain.calendar.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.calendar.catalog_suggestion_claimed",
        return_value=True,
    ), patch(
        "lanonna_api.domain.calendar.create_event",
    ) as create_mock:
        with pytest.raises(ValueError, match="already on the calendar"):
            create_calendar_event(
                "uid",
                baby_id,
                title="Baby shower",
                starts_at=starts,
                ends_at=None,
                description=None,
                location=None,
                video_call_url=None,
                cover_photo_id=None,
                catalog_suggestion_id="baby_shower",
            )
        create_mock.assert_not_called()


def test_create_event_passes_catalog_suggestion_id():
    baby_id = uuid.uuid4()
    starts = datetime(2026, 6, 1, 12, 0, tzinfo=timezone.utc)
    with patch(
        "lanonna_api.domain.calendar.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.calendar.catalog_suggestion_claimed",
        return_value=False,
    ), patch(
        "lanonna_api.domain.calendar.upsert_app_user",
    ), patch(
        "lanonna_api.domain.calendar.insert_activity_event",
    ), patch(
        "lanonna_api.domain.calendar.safe_enqueue_fan_out",
    ), patch(
        "lanonna_api.domain.calendar.create_event",
        return_value={
            "id": uuid.uuid4(),
            "title": "Baby shower",
            "starts_at": starts,
            "catalog_suggestion_id": "baby_shower",
        },
    ) as create_mock, patch(
        "lanonna_api.domain.calendar._event_row_to_json",
        return_value={"id": "x", "catalog_suggestion_id": "baby_shower"},
    ):
        create_calendar_event(
            "uid",
            baby_id,
            title="Baby shower",
            starts_at=starts,
            ends_at=None,
            description=None,
            location=None,
            video_call_url=None,
            cover_photo_id=None,
            catalog_suggestion_id="baby_shower",
        )
        assert create_mock.call_args.kwargs["catalog_suggestion_id"] == "baby_shower"


