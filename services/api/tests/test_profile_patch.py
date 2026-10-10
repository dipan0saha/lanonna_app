from datetime import date, datetime, timezone
from unittest.mock import patch

from lanonna_api.repositories.users import patch_profile_fields


def test_patch_profile_fields_only_updates_provided_columns():
    executed: list[tuple] = []

    class FakeCursor:
        def fetchone(self):
            return {
                "firebase_uid": "uid",
                "email": "a@b.com",
                "display_name": "Sarah Parker",
                "avatar_url": None,
                "phone": "555",
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
                "created_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc),
            }

    class FakeConn:
        def execute(self, sql, params):
            executed.append((sql, params))
            return FakeCursor()

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

    with patch(
        "lanonna_api.repositories.users.get_connection",
        return_value=FakeConn(),
    ):
        patch_profile_fields("uid", {"birth_date": date(1991, 1, 1)})

    sql, params = executed[0]
    assert "birth_date = %s" in sql
    assert "display_name =" not in sql
    assert params[0] == date(1991, 1, 1)
