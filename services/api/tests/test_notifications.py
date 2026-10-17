"""Publishers send structured notifications (kind + actor + params), never copy."""

from __future__ import annotations

from uuid import uuid4
from unittest.mock import patch

from lanonna_activity_copy import NotificationKind

from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    NotifyUserSpec,
    enqueue_fan_out,
    enqueue_notify_user,
    safe_enqueue_fan_out,
    safe_enqueue_notify_user,
)


def test_enqueue_fan_out_publishes_kind_actor_and_params():
    baby_id = uuid4()
    with patch("lanonna_api.domain.notifications.publish_notify_fan_out") as publish:
        enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_id,
                kind=NotificationKind.EVENT_CREATED,
                params={"event_title": "Shower"},
                deep_link="/calendar/event/x",
                actor_firebase_uid="actor-1",
            )
        )
    kwargs = publish.call_args.kwargs
    assert kwargs["kind"] == "event_created"
    assert kwargs["params"] == {"event_title": "Shower"}
    assert kwargs["actor_firebase_uid"] == "actor-1"
    assert not {"title", "body", "notification_type", "actor_display_name"} & set(kwargs)


def test_enqueue_notify_user_publishes_kind_actor_and_params():
    with patch("lanonna_api.domain.notifications.publish_notify_user") as publish:
        enqueue_notify_user(
            NotifyUserSpec(
                firebase_uid="owner-1",
                kind=NotificationKind.EVENT_RSVP,
                params={"event_title": "Shower", "rsvp_status": "going"},
                deep_link="/calendar/event/x",
                actor_firebase_uid="actor-1",
            )
        )
    kwargs = publish.call_args.kwargs
    assert kwargs["firebase_uid"] == "owner-1"
    assert kwargs["kind"] == "event_rsvp"
    assert kwargs["params"]["rsvp_status"] == "going"
    assert "title" not in kwargs and "body" not in kwargs


def test_pubsub_payload_shape():
    sent = {}
    with patch("lanonna_api.pubsub._publish_worker_payload", side_effect=sent.update):
        from lanonna_api.pubsub import publish_notify_user

        publish_notify_user(
            firebase_uid="u",
            kind="photo_squished",
            params={},
            deep_link="/gallery/photo/p",
            baby_profile_id=None,
            actor_firebase_uid="a",
        )
    assert sent["type"] == "notify_user"
    assert sent["kind"] == "photo_squished"
    assert sent["params"] == {}
    assert "title" not in sent


def test_enqueue_fan_out_passes_recipients_and_channel():
    baby_id = uuid4()
    with patch("lanonna_api.domain.notifications.publish_notify_fan_out") as pub:
        enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_id,
                kind=NotificationKind.REGISTRY_BUYING,
                deep_link="/registry",
                actor_firebase_uid="actor",
                recipient_mode="baby_owners",
                exclude_firebase_uid="actor",
                notification_channel=NotificationChannel.REGISTRY,
            )
        )
    kwargs = pub.call_args.kwargs
    assert kwargs["baby_profile_id"] == baby_id
    assert kwargs["recipient_mode"] == "baby_owners"
    assert kwargs["exclude_firebase_uid"] == "actor"
    assert kwargs["notification_channel"] == "registry"


def test_safe_enqueue_notify_user_swallows_pubsub_errors():
    with patch(
        "lanonna_api.domain.notifications.publish_notify_user",
        side_effect=RuntimeError("pubsub unavailable"),
    ):
        safe_enqueue_notify_user(
            NotifyUserSpec(
                firebase_uid="uid-1",
                kind=NotificationKind.PHOTO_SQUISHED,
                deep_link="/gallery",
                actor_firebase_uid="a",
            )
        )


def test_safe_enqueue_fan_out_swallows_pubsub_errors():
    with patch(
        "lanonna_api.domain.notifications.publish_notify_fan_out",
        side_effect=RuntimeError("pubsub unavailable"),
    ):
        safe_enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=uuid4(),
                kind=NotificationKind.EVENT_CREATED,
                deep_link="/home",
                actor_firebase_uid="a",
            )
        )
