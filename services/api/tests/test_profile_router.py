from contextlib import contextmanager
from datetime import date, datetime, timezone
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "user-1"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": "u@test.com"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def _profile_row(**overrides):
    base = {
        "firebase_uid": "user-1",
        "email": "u@test.com",
        "display_name": "Sarah Parker",
        "avatar_url": None,
        "phone": "5550100",
        "birth_date": date(1990, 4, 12),
        "country_code": "US",
        "postal_code": "10001",
        "terms_accepted_at": datetime.now(timezone.utc),
        "owner_onboarding_completed_at": None,
        "notification_digest": None,
        "push_notifications_enabled": True,
        "email_digest_enabled": True,
        "notify_gallery_enabled": True,
        "notify_calendar_enabled": True,
        "notify_registry_enabled": True,
        "notify_comments_enabled": True,
        "biometric_unlock_enabled": False,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    base.update(overrides)
    return base


@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_patch_profile_birth_date_only(mock_patch):
    mock_patch.return_value = _profile_row(birth_date=date(1991, 1, 1))
    with _auth_as():
        response = client.patch("/v1/profile", json={"birth_date": "1991-01-01"})
    assert response.status_code == 200
    mock_patch.assert_called_once()
    changes = mock_patch.call_args[0][1]
    assert list(changes.keys()) == ["birth_date"]
    assert response.json()["phone"] == "5550100"


@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_patch_profile_without_display_name(mock_patch):
    mock_patch.return_value = _profile_row()
    with _auth_as():
        response = client.patch("/v1/profile", json={"phone": "5559999"})
    assert response.status_code == 200
    changes = mock_patch.call_args[0][1]
    assert "display_name" not in changes


def test_patch_profile_rejects_future_birth_date():
    with _auth_as():
        response = client.patch("/v1/profile", json={"birth_date": "2030-01-01"})
    assert response.status_code == 400
    assert response.json()["detail"]["error"] == "birth_date_in_future"


def test_patch_profile_rejects_implausibly_old_birth_date():
    with _auth_as():
        response = client.patch("/v1/profile", json={"birth_date": "1800-01-01"})
    assert response.status_code == 400
    assert response.json()["detail"]["error"] == "invalid_birth_date"


@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_patch_profile_explicit_null_clears_birth_date(mock_patch):
    mock_patch.return_value = _profile_row(birth_date=None)
    with _auth_as():
        response = client.patch("/v1/profile", json={"birth_date": None})
    assert response.status_code == 200
    assert mock_patch.call_args[0][1]["birth_date"] is None


@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_patch_profile_normalizes_phone(mock_patch):
    mock_patch.return_value = _profile_row(phone="+15550101234")
    with _auth_as():
        response = client.patch(
            "/v1/profile",
            json={"phone": "+1 (555) 010-1234"},
        )
    assert response.status_code == 200
    assert mock_patch.call_args[0][1]["phone"] == "+15550101234"
    assert response.json()["phone"] == "+15550101234"


def test_patch_profile_rejects_invalid_phone():
    with _auth_as():
        response = client.patch("/v1/profile", json={"phone": "abc"})
    assert response.status_code == 422


def test_patch_profile_rejects_blank_display_name():
    with _auth_as():
        response = client.patch("/v1/profile", json={"display_name": "   "})
    assert response.status_code == 422


@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_patch_profile_biometric_unlock_enabled(mock_patch):
    mock_patch.return_value = _profile_row(biometric_unlock_enabled=True)
    with _auth_as():
        response = client.patch(
            "/v1/profile",
            json={"biometric_unlock_enabled": True},
        )
    assert response.status_code == 200
    changes = mock_patch.call_args[0][1]
    assert changes == {"biometric_unlock_enabled": True}
    assert response.json()["biometric_unlock_enabled"] is True


@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_patch_profile_explicit_null_clears_phone(mock_patch):
    mock_patch.return_value = _profile_row(phone=None)
    with _auth_as():
        response = client.patch("/v1/profile", json={"phone": None})
    assert response.status_code == 200
    assert mock_patch.call_args[0][1]["phone"] is None


@patch("lanonna_api.routers.profile.revoke_user_biometric_credentials")
@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_turning_biometrics_off_revokes_device_credentials(mock_patch, mock_revoke):
    mock_patch.return_value = _profile_row(biometric_unlock_enabled=False)
    with _auth_as():
        response = client.patch("/v1/profile", json={"biometric_unlock_enabled": False})
    assert response.status_code == 200
    mock_revoke.assert_called_once_with("user-1")


@patch("lanonna_api.routers.profile.revoke_user_biometric_credentials")
@patch("lanonna_api.routers.profile.patch_profile_fields")
def test_turning_biometrics_on_keeps_device_credentials(mock_patch, mock_revoke):
    mock_patch.return_value = _profile_row(biometric_unlock_enabled=True)
    with _auth_as():
        response = client.patch("/v1/profile", json={"biometric_unlock_enabled": True})
    assert response.status_code == 200
    mock_revoke.assert_not_called()
