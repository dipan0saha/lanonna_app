import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def as_user(uid: str, email: str = "o@test.com"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": email}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_list_members_includes_can_remove():
    baby_id = uuid.uuid4()
    with (
        as_user("owner-1"),
        patch("lanonna_api.routers.members.upsert_app_user"),
        patch(
            "lanonna_api.routers.members.list_members_for_owner",
            return_value=[
                {
                    "firebase_uid": "f1",
                    "display_name": "A",
                    "role": "follower",
                    "can_remove": True,
                    "created_at": "2026-01-01T00:00:00+00:00",
                },
            ],
        ),
    ):
        resp = client.get(f"/v1/babies/{baby_id}/members")
    assert resp.status_code == 200
    assert resp.json()[0]["can_remove"] is True
    assert resp.json()[0]["firebase_uid"] == "f1"


def test_delete_member_returns_204():
    baby_id = uuid.uuid4()
    with (
        as_user("owner-1"),
        patch("lanonna_api.routers.members.upsert_app_user"),
        patch("lanonna_api.routers.members.remove_member"),
    ):
        resp = client.delete(f"/v1/babies/{baby_id}/members/follower-1")
    assert resp.status_code == 204


def test_leave_returns_204():
    baby_id = uuid.uuid4()
    with (
        as_user("follower-1"),
        patch("lanonna_api.routers.members.upsert_app_user"),
        patch("lanonna_api.routers.members.leave_baby_profile"),
    ):
        resp = client.post(f"/v1/babies/{baby_id}/leave")
    assert resp.status_code == 204
