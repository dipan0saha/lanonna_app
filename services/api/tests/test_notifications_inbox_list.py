from types import MappingProxyType
from contextlib import contextmanager
from datetime import datetime, timezone
from unittest.mock import patch
from uuid import uuid4

from fastapi.testclient import TestClient

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "user-1"):
    app.dependency_overrides[current_app_user] = lambda: AppUser(
        uid=uid,
        email="u@test.com",
        display_name=None,
        claims=MappingProxyType({"uid": uid}),
    )
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_app_user, None)


@patch("lanonna_api.routers.notifications.list_notifications_for_user")
def test_list_notifications_returns_offset_page(mock_list):
    now = datetime.now(timezone.utc)
    mock_list.return_value = [
        {
            "id": uuid4(),
            "baby_profile_id": None,
            "title": "Hi",
            "body": "There",
            "deep_link": "/home",
            "notification_type": "generic",
            "actor_firebase_uid": None,
            "actor_display_name": None,
            "read_at": None,
            "created_at": now,
        }
    ]
    with _auth_as():
        response = client.get("/v1/me/notifications?limit=50&offset=0")
    assert response.status_code == 200
    payload = response.json()
    assert set(payload.keys()) == {"items", "offset", "limit", "has_more"}
    assert len(payload["items"]) == 1
    assert payload["has_more"] is False
    mock_list.assert_called_once_with("user-1", limit=51, offset=0)
