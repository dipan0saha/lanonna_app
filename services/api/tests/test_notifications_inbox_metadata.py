from __future__ import annotations

from unittest.mock import patch

from lanonna_api.domain.notification_metadata import NotificationType
from lanonna_api.domain.notifications import FanOutSpec, enqueue_fan_out


def test_enqueue_fan_out_includes_structured_metadata():
    with patch("lanonna_api.domain.notifications.publish_notify_fan_out") as publish:
        from uuid import uuid4

        baby_id = uuid4()
        enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_id,
                title="New event",
                body='"Shower" was added',
                deep_link="/calendar/event/x",
                notification_type=NotificationType.EVENT,
                actor_firebase_uid="actor-1",
            )
        )
        publish.assert_called_once()
        kwargs = publish.call_args.kwargs
        assert kwargs["notification_type"] == "event"
        assert kwargs["actor_firebase_uid"] == "actor-1"
        assert "actor_display_name" not in kwargs
