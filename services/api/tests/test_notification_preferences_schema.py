from lanonna_api.routers.profile import _notification_preferences_payload


def test_notification_preferences_payload_includes_channels():
    row = {
        "notification_digest": "weekly",
        "push_notifications_enabled": False,
        "email_digest_enabled": True,
        "notify_gallery_enabled": True,
        "notify_calendar_enabled": False,
        "notify_registry_enabled": True,
        "notify_comments_enabled": False,
    }
    out = _notification_preferences_payload(row)
    assert out["notification_digest"] == "weekly"
    assert out["notify_calendar_enabled"] is False
    assert out["notify_comments_enabled"] is False
