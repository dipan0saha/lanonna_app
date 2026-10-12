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
    assert "End time must be at or after" in response.json()["detail"]
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
    assert "End time must be at or after" in response.json()["detail"]
    update_mock.assert_not_called()
