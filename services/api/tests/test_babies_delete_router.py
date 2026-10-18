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


def test_delete_baby_returns_204():
    baby_id = uuid.uuid4()
    with (
        as_user("owner-1"),
        patch("lanonna_api.routers.babies.delete_baby_profile"),
    ):
        resp = client.delete(f"/v1/babies/{baby_id}")
    assert resp.status_code == 204


def test_delete_shared_baby_returns_409():
    from lanonna_api.domain.baby_delete import CannotDeleteSharedBabyError

    with (
        as_user("owner-1"),
        patch(
            "lanonna_api.routers.babies.delete_baby_profile",
            side_effect=CannotDeleteSharedBabyError(),
        ),
    ):
        resp = client.delete(f"/v1/babies/{uuid.uuid4()}")
    assert resp.status_code == 409
    assert resp.json()["detail"]["error"] == "cannot_delete_shared_baby"


def test_delete_by_non_owner_returns_403():
    with (
        as_user("follower-1"),
        patch(
            "lanonna_api.routers.babies.delete_baby_profile",
            side_effect=PermissionError("Owner access required"),
        ),
    ):
        resp = client.delete(f"/v1/babies/{uuid.uuid4()}")
    assert resp.status_code == 403
