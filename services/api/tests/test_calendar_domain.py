import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest

from lanonna_api.domain.calendar import (
    _parse_month,
    add_event_comment,
    create_calendar_event,
    set_rsvp,
)
from lanonna_api.domain.url_validation import INVALID_HTTP_URL


def test_parse_month_january():
    start, end = _parse_month("2026-01")
    assert start == datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert end == datetime(2026, 2, 1, tzinfo=timezone.utc)


def test_parse_month_december():
    start, end = _parse_month("2025-12")
    assert start == datetime(2025, 12, 1, tzinfo=timezone.utc)
    assert end == datetime(2026, 1, 1, tzinfo=timezone.utc)


def test_create_event_rejects_invalid_video_call_url():
    baby_id = uuid.uuid4()
    starts = datetime(2026, 6, 1, 12, 0, tzinfo=timezone.utc)
    with patch(
        "lanonna_api.domain.calendar.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.calendar.create_event",
    ) as create_mock:
        with pytest.raises(ValueError, match=INVALID_HTTP_URL):
            create_calendar_event(
                "uid",
                baby_id,
                title="Call",
                starts_at=starts,
                ends_at=None,
                description=None,
                location=None,
                video_call_url="javascript:alert(1)",
                cover_photo_id=None,
            )
        create_mock.assert_not_called()


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


def test_set_rsvp_succeeds_when_notify_enqueue_fails():
    baby_id = uuid.uuid4()
    event_id = uuid.uuid4()
    event = {
        "title": "Baby shower",
        "created_by_firebase_uid": "creator-uid",
    }
    with patch("lanonna_api.domain.calendar.require_membership"), patch(
        "lanonna_api.domain.calendar.get_event",
        return_value=event,
    ), patch(
        "lanonna_api.domain.calendar.upsert_app_user",
    ), patch(
        "lanonna_api.domain.calendar.upsert_rsvp",
    ), patch(
        "lanonna_api.domain.calendar.actor_display_name",
        return_value="Alex",
    ), patch(
        "lanonna_api.domain.notifications.publish_notify_user",
        side_effect=RuntimeError("pubsub down"),
    ):
        result = set_rsvp("rsvp-uid", baby_id, event_id, "going")
    assert result == {"status": "going"}


def test_add_event_comment_succeeds_when_notify_enqueue_fails():
    baby_id = uuid.uuid4()
    event_id = uuid.uuid4()
    event = {
        "title": "Baby shower",
        "created_by_firebase_uid": "creator-uid",
    }
    with patch("lanonna_api.domain.calendar.require_membership"), patch(
        "lanonna_api.domain.calendar.get_event",
        return_value=event,
    ), patch(
        "lanonna_api.domain.calendar.upsert_app_user",
    ), patch(
        "lanonna_api.domain.calendar.insert_event_comment",
        return_value={
            "id": uuid.uuid4(),
            "body": "See you there",
            "created_at": datetime(2026, 6, 1, tzinfo=timezone.utc),
        },
    ), patch(
        "lanonna_api.domain.calendar.actor_display_name",
        return_value="Alex",
    ), patch(
        "lanonna_api.domain.notifications.publish_notify_user",
        side_effect=RuntimeError("pubsub down"),
    ):
        result = add_event_comment(
            "comment-uid", baby_id, event_id, "See you there"
        )
    assert result["body"] == "See you there"


