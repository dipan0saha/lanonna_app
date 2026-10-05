import uuid
from contextlib import contextmanager
from unittest.mock import patch

import pytest
from firebase_admin import auth as firebase_auth
from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.domain.account_delete import (
    delete_account,
    delete_account_eligibility,
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


def test_eligibility_allowed_even_with_sole_owned_babies():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
        return_value=[baby_id],
    ):
        result = delete_account_eligibility("uid")
    assert result["allowed"] is True
    assert result["blockers"] == []


def test_delete_account_eligibility_route():
    with (
        _auth_as(),
        patch("lanonna_api.routers.profile.upsert_app_user"),
        patch(
            "lanonna_api.domain.account_delete.delete_account_eligibility",
            return_value={"allowed": True, "blockers": []},
        ),
    ):
        response = client.get("/v1/me/delete-account/eligibility")
    assert response.status_code == 200
    assert response.json() == {"allowed": True, "blockers": []}


def test_delete_account_firebase_before_sql():
    with (
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[],
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
        ) as delete_user,
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
        ) as soft_delete,
    ):
        delete_account("uid-1")
    delete_user.assert_called_once_with("uid-1")
    soft_delete.assert_called_once_with("uid-1", [])


def test_delete_account_passes_sole_owned_babies_to_sql():
    baby_id = uuid.uuid4()
    with (
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


def test_delete_account_firebase_failure_does_not_soft_delete():
    with (
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
    soft_delete.assert_not_called()


def test_delete_account_continues_when_firebase_user_missing():
    with (
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
