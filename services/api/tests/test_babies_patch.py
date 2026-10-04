import uuid
from contextlib import contextmanager
from datetime import date
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


def test_patch_baby_born_invokes_announce_arrival():
    baby_id = uuid.uuid4()
    birth = date(2026, 10, 1)
    row = {
        "id": baby_id,
        "name": "Baby",
        "gender": "unknown",
        "expected_birth_date": date(2026, 9, 1),
        "actual_birth_date": birth,
        "lifecycle_status": "born",
        "role": "owner",
        "relationship_label": None,
        "avatar_url": None,
    }
    with (
        _auth_as(),
        patch("lanonna_api.routers.babies.upsert_app_user"),
        patch("lanonna_api.routers.babies.announce_arrival", return_value=row) as announce,
    ):
        response = client.patch(
            f"/v1/babies/{baby_id}",
            json={
                "lifecycle_status": "born",
                "actual_birth_date": birth.isoformat(),
            },
        )

    assert response.status_code == 200
    announce.assert_called_once()
    call_args = announce.call_args
    assert call_args.args[0] == "owner-1"
    assert call_args.args[1] == baby_id
    assert call_args.args[2] == birth
