"""Baby name is optional: an unnamed baby is stored as NULL, never a
placeholder such as "Baby" (L-36)."""

import uuid
from contextlib import contextmanager
from datetime import date
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app
from lanonna_api.schemas.babies import BabyCreateRequest, BabyUpdateRequest

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "owner-1"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": "o@test.com"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def _row(baby_id: uuid.UUID, name: str | None) -> dict:
    return {
        "id": baby_id,
        "name": name,
        "gender": "unknown",
        "expected_birth_date": date(2026, 12, 1),
        "actual_birth_date": None,
        "lifecycle_status": "expecting",
        "role": "owner",
        "active_owner_count": 1,
        "relationship_label": "Mother",
        "avatar_url": None,
    }


def test_create_request_name_is_optional_and_blank_means_none():
    assert BabyCreateRequest().name is None
    assert BabyCreateRequest(name="   ").name is None
    assert BabyCreateRequest(name="  Liam ").name == "Liam"
    assert BabyCreateRequest().gender == "unknown"


def test_update_request_keeps_the_raw_name_so_null_means_unchanged():
    assert BabyUpdateRequest().name is None
    assert BabyUpdateRequest(name=None).name is None
    assert BabyUpdateRequest(name=" ").name == " "


def test_create_without_name_stores_null_and_returns_null():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch(
            "lanonna_api.routers.babies.create_baby_with_owner_membership",
            return_value=_row(baby_id, None),
        ) as create,
    ):
        response = client.post("/v1/babies", json={"lifecycle_status": "expecting"})

    assert response.status_code == 201
    assert create.call_args.args[1] is None  # name
    assert create.call_args.args[2] == "unknown"  # gender
    assert response.json()["name"] is None


def test_patch_with_blank_name_clears_it():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch(
            "lanonna_api.routers.babies.update_baby_profile",
            return_value=_row(baby_id, None),
        ) as update,
    ):
        response = client.patch(f"/v1/babies/{baby_id}", json={"name": "  "})

    assert response.status_code == 200
    assert update.call_args.args[2] == {"name": None}
    assert response.json()["name"] is None


def test_patch_with_null_or_missing_name_leaves_it_unchanged():
    """Older app builds send every key, ``"name": null`` included."""
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch(
            "lanonna_api.routers.babies.update_baby_profile",
            return_value=_row(baby_id, "Liam"),
        ) as update,
    ):
        response = client.patch(f"/v1/babies/{baby_id}", json={"name": None, "avatar_url": None, "gender": "male"})

    assert response.status_code == 200
    assert update.call_args.args[2] == {"gender": "male"}


def test_announce_arrival_can_clear_the_name_in_the_same_patch():
    baby_id = uuid.uuid4()
    birth = date(2026, 10, 1)
    with (
        _auth_as(),
        patch(
            "lanonna_api.routers.babies.announce_arrival",
            return_value=_row(baby_id, None) | {"lifecycle_status": "born", "actual_birth_date": birth},
        ) as announce,
    ):
        response = client.patch(
            f"/v1/babies/{baby_id}",
            json={"name": "", "lifecycle_status": "born", "actual_birth_date": birth.isoformat()},
        )

    assert response.status_code == 200
    assert announce.call_args.kwargs["extra_fields"] == {"name": None}
