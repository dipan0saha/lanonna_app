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


def test_patch_baby_non_owner_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as("follower-1"),
        patch(
            "lanonna_api.routers.babies.require_owner_baby",
            side_effect=PermissionError("Owner access required"),
        ),
    ):
        response = client.patch(
            f"/v1/babies/{baby_id}",
            json={"name": "Nope"},
        )
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "forbidden"


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
        "active_owner_count": 1,
        "relationship_label": None,
        "avatar_url": None,
    }
    with (
        _auth_as(),        patch("lanonna_api.routers.babies.announce_arrival", return_value=row) as announce,
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


def test_patch_baby_seeds_profile_name_suggestions_when_expecting():
    baby_id = uuid.uuid4()
    row = {
        "id": baby_id,
        "name": "Baby",
        "gender": "unknown",
        "expected_birth_date": date(2026, 12, 1),
        "actual_birth_date": None,
        "lifecycle_status": "expecting",
        "role": "owner",
        "active_owner_count": 1,
        "relationship_label": None,
        "avatar_url": None,
    }
    with (
        _auth_as(),
        patch(
            "lanonna_api.routers.babies.update_baby_for_owner",
            return_value=row,
        ) as update,
        patch(
            "lanonna_api.routers.babies.seed_expecting_profile_name_suggestions",
            return_value=1,
        ) as seed,
    ):
        response = client.patch(
            f"/v1/babies/{baby_id}",
            json={
                "name": "Baby",
                "profile_name_suggestions": [
                    {"name": "Liam", "gender": "male"},
                ],
            },
        )

    assert response.status_code == 200
    update.assert_called_once()
    seed.assert_called_once()
    assert seed.call_args.kwargs["baby"] == row
