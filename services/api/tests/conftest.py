"""Keep unit tests off the database. Integration tests opt out."""

from datetime import datetime, timezone

import pytest


def _stub_row(firebase_uid: str, email: str | None) -> dict:
    now = datetime.now(timezone.utc)
    return {
        "firebase_uid": firebase_uid,
        "email": email,
        "display_name": None,
        "avatar_url": None,
        "phone": None,
        "birth_date": None,
        "country_code": None,
        "postal_code": None,
        "terms_accepted_at": None,
        "owner_onboarding_completed_at": None,
        "notification_digest": "realtime",
        "push_notifications_enabled": True,
        "notify_gallery_enabled": True,
        "notify_calendar_enabled": True,
        "notify_registry_enabled": True,
        "notify_comments_enabled": True,
        "biometric_unlock_enabled": False,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
        "last_seen_at": now,
    }


@pytest.fixture(autouse=True)
def _stub_resolve_app_user(request, monkeypatch):
    """Authenticated routes provision through resolve_app_user. Unit tests stub it."""
    if request.node.get_closest_marker("integration"):
        yield
        return

    def fake(firebase_uid: str, email: str | None = None) -> dict:
        return _stub_row(firebase_uid, email)

    monkeypatch.setattr("lanonna_api.auth.resolve_app_user", fake)
    yield
