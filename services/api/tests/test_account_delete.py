import uuid
from contextlib import contextmanager
from unittest.mock import patch

import pytest
from firebase_admin import auth as firebase_auth
from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.domain.account_delete import (
    delete_account,
    delete_account_preview,
)
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "uid-1", email: str = "user@test.com"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": email}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


@pytest.fixture(autouse=True)
def _no_storage_cleanup_io():
    """Storage cleanup enqueueing is covered in test_account_delete_storage.py."""
    with (
        patch("lanonna_api.domain.account_delete.enqueue_storage_cleanup"),
        patch(
            "lanonna_api.domain.account_delete.account_cleanup_job_needs_publish",
            return_value=None,
        ),
    ):
        yield


def test_preview_lists_sole_owned_babies_only():
    """Deletion is never blocked (FR-SET-005); the preview has no gate fields."""
    with patch(
        "lanonna_api.domain.account_delete.list_sole_owned_baby_names",
        return_value=[{"id": "baby-1", "name": "Liam"}],
    ):
        result = delete_account_preview("uid")
    assert result == {"sole_owned_babies": [{"id": "baby-1", "name": "Liam"}]}


def test_delete_account_preview_route():
    babies = [{"id": "baby-1", "name": "Liam"}]
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_names",
            return_value=babies,
        ),
    ):
        response = client.get("/v1/me/delete-account/preview")
    assert response.status_code == 200
    assert response.json() == {"sole_owned_babies": babies}
    assert client.get("/v1/me/delete-account/eligibility").status_code == 404


def test_delete_account_sql_before_firebase():
    order: list[str] = []
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[],
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
            side_effect=lambda uid: order.append("firebase"),
        ),
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
            side_effect=lambda uid, sole: order.append("sql"),
        ),
    ):
        delete_account("uid-1")
    assert order == ["sql", "firebase"]


def test_delete_account_passes_sole_owned_babies_to_sql():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[baby_id],
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
        ),
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
        ) as soft_delete,
    ):
        delete_account("uid-sole")
    soft_delete.assert_called_once_with("uid-sole", [baby_id])


def test_delete_account_firebase_failure_after_sql():
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[],
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
            side_effect=RuntimeError("firebase down"),
        ),
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
        ) as soft_delete,
    ):
        with pytest.raises(RuntimeError, match="Could not delete Firebase user"):
            delete_account("uid-2")
    soft_delete.assert_called_once()


def test_delete_account_retry_skips_sql_when_tombstoned():
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
        ) as list_sole,
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
        ) as delete_user,
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
        ) as soft_delete,
    ):
        delete_account("uid-retry")
    list_sole.assert_not_called()
    soft_delete.assert_not_called()
    delete_user.assert_called_once_with("uid-retry")


def test_delete_account_continues_when_firebase_user_missing():
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[],
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
            side_effect=firebase_auth.UserNotFoundError("missing"),
        ),
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
        ) as soft_delete,
    ):
        delete_account("uid-3")
    soft_delete.assert_called_once_with("uid-3", [])


def test_delete_account_route_passes_token_uid_to_domain():
    """The route depends on ``current_user`` (verified claims dict), not ``AppUser``."""
    with (
        _auth_as("uid-route"),
        patch("lanonna_api.routers.profile.delete_account") as delete,
    ):
        resp = client.post("/v1/me/delete-account", json={"confirm": True})
    assert resp.status_code == 200
    assert resp.json() == {"status": "deleted"}
    delete.assert_called_once_with("uid-route")


def test_delete_account_route_requires_confirm():
    with (
        _auth_as("uid-route"),
        patch("lanonna_api.routers.profile.delete_account") as delete,
    ):
        resp = client.post("/v1/me/delete-account", json={"confirm": False})
    assert resp.status_code == 400
    delete.assert_not_called()
