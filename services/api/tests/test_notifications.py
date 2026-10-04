import uuid
from unittest.mock import patch

from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    enqueue_fan_out,
    enqueue_notify_user,
    safe_enqueue_fan_out,
)


def test_enqueue_fan_out_publishes_payload():
    baby_id = uuid.uuid4()
    with patch("lanonna_api.domain.notifications.publish_notify_fan_out") as pub:
        enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_id,
                title="T",
                body="B",
                deep_link="/home",
                recipient_mode="baby_owners",
                exclude_firebase_uid="actor",
                notification_channel=NotificationChannel.REGISTRY,
            )
        )
        pub.assert_called_once()
        kwargs = pub.call_args.kwargs
        assert kwargs["baby_profile_id"] == baby_id
        assert kwargs["recipient_mode"] == "baby_owners"
        assert kwargs["exclude_firebase_uid"] == "actor"
        assert kwargs["notification_channel"] == "registry"


def test_enqueue_notify_user_publishes():
    with patch("lanonna_api.domain.notifications.publish_notify_user") as pub:
        enqueue_notify_user(
            "uid-1",
            title="Hi",
            body="There",
            deep_link="/gallery",
        )
        pub.assert_called_once_with(
            firebase_uid="uid-1",
            title="Hi",
            body="There",
            deep_link="/gallery",
            baby_profile_id=None,
            notification_channel=None,
        )


def test_safe_enqueue_fan_out_swallows_pubsub_errors():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.notifications.publish_notify_fan_out",
        side_effect=RuntimeError("pubsub unavailable"),
    ):
        safe_enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_id,
                title="T",
                body="B",
                deep_link="/home",
            )
        )
