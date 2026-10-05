import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "owner-1", email: str = "owner@test.com"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": email}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_data_export_forbidden_for_non_owner():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.data_export.upsert_app_user"),
        patch(
            "lanonna_api.domain.data_export.get_baby_for_owner",
            return_value=None,
        ),
    ):
        response = client.post(f"/v1/babies/{baby_id}/data-export", json={})
    assert response.status_code == 403


def test_data_export_happy_path():
    baby_id = uuid.uuid4()
    job_id = uuid.uuid4()
    created = datetime(2026, 10, 1, tzinfo=timezone.utc)
    with (
        _auth_as(),
        patch("lanonna_api.routers.data_export.upsert_app_user"),
        patch(
            "lanonna_api.domain.data_export.get_baby_for_owner",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.data_export.insert_export_job",
            return_value={
                "id": job_id,
                "baby_profile_id": baby_id,
                "status": "pending",
                "object_path": None,
                "error_message": None,
                "created_at": created,
                "completed_at": None,
            },
        ),
        patch("lanonna_api.domain.data_export.publish_baby_data_export"),
    ):
        response = client.post(f"/v1/babies/{baby_id}/data-export", json={})
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(job_id)
    assert body["status"] == "pending"


def test_data_export_pubsub_failure_marks_failed():
    baby_id = uuid.uuid4()
    job_id = uuid.uuid4()
    created = datetime(2026, 10, 1, tzinfo=timezone.utc)
    with (
        _auth_as(),
        patch("lanonna_api.routers.data_export.upsert_app_user"),
        patch(
            "lanonna_api.domain.data_export.get_baby_for_owner",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.data_export.insert_export_job",
            return_value={
                "id": job_id,
                "baby_profile_id": baby_id,
                "status": "pending",
                "object_path": None,
                "error_message": None,
                "created_at": created,
                "completed_at": None,
            },
        ),
        patch(
            "lanonna_api.domain.data_export.publish_baby_data_export",
            side_effect=RuntimeError("pubsub down"),
        ),
        patch("lanonna_api.domain.data_export.mark_export_job_failed") as failed,
    ):
        response = client.post(f"/v1/babies/{baby_id}/data-export", json={})
    assert response.status_code == 503
    failed.assert_called_once()


def test_data_export_latest_not_found():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.data_export.upsert_app_user"),
        patch(
            "lanonna_api.domain.data_export.get_baby_for_owner",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.data_export.get_latest_export_job_for_baby",
            return_value=None,
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/data-export/latest")
    assert response.status_code == 404


def test_data_export_latest_ready_includes_download_url():
    baby_id = uuid.uuid4()
    job_id = uuid.uuid4()
    created = datetime(2026, 10, 1, tzinfo=timezone.utc)
    with (
        _auth_as(),
        patch("lanonna_api.routers.data_export.upsert_app_user"),
        patch(
            "lanonna_api.domain.data_export.get_baby_for_owner",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.data_export.get_latest_export_job_for_baby",
            return_value={
                "id": job_id,
                "baby_profile_id": baby_id,
                "status": "ready",
                "object_path": "exports/foo.zip",
                "error_message": None,
                "created_at": created,
                "completed_at": created,
            },
        ),
        patch(
            "lanonna_api.domain.data_export.mint_signed_read_url",
            return_value="https://signed.example/export.zip",
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/data-export/latest")
    assert response.status_code == 200
    assert response.json()["download_url"] == "https://signed.example/export.zip"
