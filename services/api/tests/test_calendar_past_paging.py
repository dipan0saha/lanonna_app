from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import patch
from uuid import uuid4

from lanonna_api.domain.calendar import list_calendar_events


def _event_row(n: int) -> dict:
    return {
        "id": uuid4(),
        "title": f"E{n}",
        "description": None,
        "starts_at": datetime.now(timezone.utc),
        "ends_at": None,
        "location": None,
        "video_call_url": None,
        "cover_photo_id": None,
        "catalog_suggestion_id": None,
    }


def test_past_events_returns_paginated_payload():
    rows = [_event_row(i) for i in range(3)]
    baby_id = uuid4()
    with patch("lanonna_api.domain.calendar.list_events", return_value=rows):
        with patch("lanonna_api.domain.calendar.require_membership"):
            payload = list_calendar_events(
                "uid",
                baby_id,
                past=True,
                offset=0,
                limit=2,
            )
    assert isinstance(payload, dict)
    assert len(payload["items"]) == 2
    assert payload["has_more"] is True
    assert payload["offset"] == 0
    assert payload["limit"] == 2
