from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.domain.auth_session import UserDeletedError, assert_active_user
from lanonna_api.main import app
from lanonna_api.repositories.users import upsert_app_user


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


@patch("lanonna_api.repositories.users.get_connection")
def test_upsert_app_user_does_not_restore_email_on_tombstone(mock_get_connection):
    conn = mock_get_connection.return_value.__enter__.return_value
    tombstone_row = {
            "firebase_uid": "uid-deleted",
            "email": None,
            "display_name": "Deleted user",
            "avatar_url": None,
            "phone": None,
            "birth_date": None,
            "country_code": None,
            "postal_code": None,
            "terms_accepted_at": None,
            "owner_onboarding_completed_at": None,
            "notification_digest": "realtime",
            "push_notifications_enabled": True,
            "email_digest_enabled": True,
            "notify_gallery_enabled": True,
            "notify_calendar_enabled": True,
            "notify_registry_enabled": True,
            "notify_comments_enabled": True,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }
    insert_result = MagicMock()
    insert_result.fetchone.return_value = None
    select_result = MagicMock()
    select_result.fetchone.return_value = tombstone_row
    conn.execute.side_effect = [insert_result, select_result]

    row = upsert_app_user("uid-deleted", "restored@example.com")
    assert row["email"] is None
    insert_sql = conn.execute.call_args_list[0][0][0]
    assert "deleted_at IS NULL" in insert_sql
