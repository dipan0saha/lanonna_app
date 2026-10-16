from types import MappingProxyType
from contextlib import contextmanager
from unittest.mock import patch

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


@patch("lanonna_api.routers.notifications.mark_all_notifications_read")
def test_mark_all_notifications_read(mock_mark_all):
    mock_mark_all.return_value = 3
    with _auth_as():
        response = client.post("/v1/me/notifications/read-all")
    assert response.status_code == 200
    assert response.json() == {"updated": 3}
    mock_mark_all.assert_called_once_with("user-1")


@patch("lanonna_api.routers.notifications.mark_all_notifications_read")
def test_mark_all_notifications_read_zero(mock_mark_all):
    mock_mark_all.return_value = 0
    with _auth_as():
        response = client.post("/v1/me/notifications/read-all")
    assert response.status_code == 200
    assert response.json() == {"updated": 0}
