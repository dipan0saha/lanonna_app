import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "owner-1"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": "o@test.com"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


@patch("lanonna_api.routers.announcements.upsert_app_user")
@patch("lanonna_api.domain.announcement.get_announcement")
@patch("lanonna_api.domain.announcement.assert_owner_membership")
def test_patch_announcement_rejects_invalid_birth_time(
    _owner,
    mock_get_ann,
    _upsert,
):
    mock_get_ann.return_value = {
        "first_name": "Baby",
        "last_name": None,
        "gender": "male",
        "birth_date": None,
        "birth_time": "10:00",
        "weight_text": None,
        "length_text": None,
        "photo_id": None,
    }
    baby_id = uuid.uuid4()
    with _auth_as():
        response = client.patch(
            f"/v1/babies/{baby_id}/announcement",
            json={"birth_time": "not-a-time"},
        )
    assert response.status_code == 400
    assert "HH:MM" in response.json()["detail"]
