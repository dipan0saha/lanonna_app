from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from lanonna_api.auth import current_app_user, current_user
from lanonna_api.domain.auth_session import assert_active_user
from lanonna_api.domain.user_errors import UserDeletedError
from lanonna_api.main import app


def test_assert_active_user_raises_when_tombstoned():
    with patch(
        "lanonna_api.domain.auth_session.get_app_user_including_tombstone",
        return_value={
            "firebase_uid": "uid-1",
            "deleted_at": datetime.now(timezone.utc),
        },
    ):
        with pytest.raises(UserDeletedError):
            assert_active_user("uid-1")


def test_assert_active_user_allows_missing_row():
    with patch(
        "lanonna_api.domain.auth_session.get_app_user_including_tombstone",
        return_value=None,
    ):
        assert_active_user("new-uid")


def test_current_user_returns_401_user_deleted():
    app.dependency_overrides.clear()

    def fake_current_user():
        raise HTTPException(
            status_code=401,
            detail={"error": "user_deleted", "message": "This account was deleted."},
        )

    app.dependency_overrides[current_user] = fake_current_user
    client = TestClient(app)
    try:
        response = client.get("/v1/me/account")
        assert response.status_code == 401
        assert response.json()["detail"]["error"] == "user_deleted"
    finally:
        app.dependency_overrides.pop(current_user, None)


def _resolve_row(**overrides):
    row = {
        "firebase_uid": "uid-1",
        "email": "same@example.com",
        "deleted_at": None,
        "seen_stale": False,
    }
    row.update(overrides)
    return row


def _result(row):
    result = MagicMock()
    result.fetchone.return_value = row
    return result


@patch("lanonna_api.repositories.users.get_connection")
def test_resolve_app_user_raises_user_deleted_on_tombstone(mock_get_connection):
    from lanonna_api.repositories.users import resolve_app_user

    conn = mock_get_connection.return_value.__enter__.return_value
    deleted_at = datetime.now(timezone.utc)
    conn.execute.side_effect = [
        _result(_resolve_row(firebase_uid="uid-deleted", email=None, deleted_at=deleted_at, seen_stale=True)),
    ]

    with pytest.raises(UserDeletedError):
        resolve_app_user("uid-deleted", "restored@example.com")

    # A tombstoned row is never written, even when stale or the email differs.
    assert conn.execute.call_count == 1
    assert "INSERT" not in conn.execute.call_args_list[0][0][0]


@patch("lanonna_api.repositories.users.get_connection")
def test_resolve_app_user_steady_state_is_one_read(mock_get_connection):
    from lanonna_api.repositories.users import resolve_app_user

    conn = mock_get_connection.return_value.__enter__.return_value
    conn.execute.side_effect = [_result(_resolve_row())]

    row = resolve_app_user("uid-1", "same@example.com")

    assert conn.execute.call_count == 1
    assert conn.execute.call_args_list[0][0][0].lstrip().startswith("SELECT")
    assert "seen_stale" not in row


@pytest.mark.parametrize(
    "existing, email",
    [
        (None, "new@example.com"),
        (_resolve_row(seen_stale=True), "same@example.com"),
        (_resolve_row(), "changed@example.com"),
    ],
    ids=["new_user", "last_seen_stale", "email_changed"],
)
@patch("lanonna_api.repositories.users.get_connection")
def test_resolve_app_user_upserts_only_when_needed(mock_get_connection, existing, email):
    from lanonna_api.repositories.users import resolve_app_user

    conn = mock_get_connection.return_value.__enter__.return_value
    written = _resolve_row(email=email)
    del written["seen_stale"]
    conn.execute.side_effect = [_result(existing), _result(written)]

    assert resolve_app_user("uid-1", email)["email"] == email

    insert_sql = conn.execute.call_args_list[1][0][0]
    assert "deleted_at IS NULL" in insert_sql
    assert "COALESCE(EXCLUDED.email, app_users.email)" in insert_sql


@patch("lanonna_api.repositories.users.get_connection")
def test_resolve_app_user_missing_email_claim_does_not_write(mock_get_connection):
    from lanonna_api.repositories.users import resolve_app_user

    conn = mock_get_connection.return_value.__enter__.return_value
    conn.execute.side_effect = [_result(_resolve_row())]

    resolve_app_user("uid-1", None)

    assert conn.execute.call_count == 1


@patch("lanonna_api.auth.verify_firebase_token", return_value={"uid": "uid-deleted"})
def test_protected_route_401_when_user_tombstoned(_verify):
    with patch(
        "lanonna_api.auth.resolve_app_user",
        side_effect=UserDeletedError(),
    ):
        client = TestClient(app)
        response = client.get(
            "/v1/me/account",
            headers={"Authorization": "Bearer test-token"},
        )
        assert response.status_code == 401
        assert response.json()["detail"]["error"] == "user_deleted"


def test_current_app_user_returns_app_user_for_active_row():
    row = {
        "firebase_uid": "uid-1",
        "email": "kept@example.com",
        "display_name": "Kept",
        "deleted_at": None,
    }
    with patch("lanonna_api.auth.resolve_app_user", return_value=row):
        user = current_app_user({"uid": "uid-1", "email": "kept@example.com"})
    assert user.uid == "uid-1"
    assert user.email == "kept@example.com"
    assert user.uid == "uid-1"
