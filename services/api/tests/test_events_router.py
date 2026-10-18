"""HTTP contract for event time-range validation."""

import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "owner-1"):
    app.dependency_overrides[current_user] = lambda: {
        "uid": uid,
        "email": "o@test.com",
    }
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_create_event_returns_400_when_end_is_before_start():
    baby_id = uuid.uuid4()
    with patch("lanonna_api.domain.calendar.assert_owner_membership"), patch(
        "lanonna_api.domain.calendar.create_event",
    ) as create_mock, _auth_as():
        response = client.post(
            f"/v1/babies/{baby_id}/events",
            json={
                "title": "Shower",
                "starts_at": "2026-06-01T12:00:00Z",
                "ends_at": "2026-06-01T11:00:00Z",
            },
        )
    assert response.status_code == 400
    assert response.json()["detail"]["error"] == "event_end_before_start"
    create_mock.assert_not_called()


def test_patch_event_returns_400_when_end_is_before_start():
    baby_id = uuid.uuid4()
    event_id = uuid.uuid4()
    starts = datetime(2026, 6, 1, 12, 0, tzinfo=timezone.utc)
    with patch("lanonna_api.domain.calendar.assert_owner_membership"), patch(
        "lanonna_api.domain.calendar.get_event",
        return_value={"starts_at": starts, "ends_at": None},
    ), patch(
        "lanonna_api.domain.calendar.update_event",
    ) as update_mock, _auth_as():
        response = client.patch(
            f"/v1/babies/{baby_id}/events/{event_id}",
            json={"ends_at": "2026-06-01T11:00:00Z"},
        )
    assert response.status_code == 400
    assert response.json()["detail"]["error"] == "event_end_before_start"
    update_mock.assert_not_called()


def test_list_events_passes_local_month_instants_to_domain():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.routers.events.calendar_domain.list_calendar_events",
        return_value={"items": [], "offset": 0, "limit": 500, "has_more": False},
    ) as list_mock, _auth_as():
        response = client.get(
            f"/v1/babies/{baby_id}/events",
            params={
                "starts_from": "2026-11-01T04:00:00.000Z",
                "starts_before": "2026-12-01T05:00:00.000Z",
            },
        )
    assert response.status_code == 200
    kwargs = list_mock.call_args.kwargs
    assert kwargs["starts_from"] == datetime(2026, 11, 1, 4, tzinfo=timezone.utc)
    assert kwargs["starts_before"] == datetime(2026, 12, 1, 5, tzinfo=timezone.utc)
    assert kwargs["month"] is None


def test_list_events_rejects_half_a_window():
    baby_id = uuid.uuid4()
    with patch("lanonna_api.domain.calendar.require_membership"), _auth_as():
        response = client.get(
            f"/v1/babies/{baby_id}/events",
            params={"starts_from": "2026-11-01T04:00:00Z"},
        )
    assert response.status_code == 400
    assert response.json()["detail"]["error"] == "invalid_request"
