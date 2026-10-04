from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from enum import StrEnum
from typing import Literal

from lanonna_api.pubsub import publish_notify_fan_out, publish_notify_user

logger = logging.getLogger("lanonna.api.notifications")

RecipientMode = Literal["baby_members", "baby_owners", "firebase_uids"]


class NotificationChannel(StrEnum):
    """Maps Pub/Sub `notification_channel` to `app_users.notify_*_enabled` columns."""

    GALLERY = "gallery"
    CALENDAR = "calendar"
    REGISTRY = "registry"
    COMMENTS = "comments"


@dataclass(frozen=True)
class FanOutSpec:
    baby_profile_id: uuid.UUID
    title: str
    body: str
    deep_link: str
    recipient_mode: RecipientMode = "baby_members"
    exclude_firebase_uid: str | None = None
    firebase_uids: tuple[str, ...] = ()
    notification_channel: NotificationChannel | None = None


def enqueue_fan_out(spec: FanOutSpec) -> None:
    publish_notify_fan_out(
        baby_profile_id=spec.baby_profile_id,
        title=spec.title,
        body=spec.body,
        deep_link=spec.deep_link,
        recipient_mode=spec.recipient_mode,
        exclude_firebase_uid=spec.exclude_firebase_uid,
        firebase_uids=list(spec.firebase_uids),
        notification_channel=(
            spec.notification_channel.value if spec.notification_channel else None
        ),
    )


def safe_enqueue_fan_out(spec: FanOutSpec) -> None:
    """Publish notify fan-out without failing the HTTP request after DB commit."""
    try:
        enqueue_fan_out(spec)
    except Exception:
        logger.exception(
            "notify_fan_out_enqueue_failed baby_profile_id=%s deep_link=%s",
            spec.baby_profile_id,
            spec.deep_link,
        )


def enqueue_notify_user(
    firebase_uid: str,
    *,
    title: str,
    body: str,
    deep_link: str,
    baby_profile_id: uuid.UUID | None = None,
    notification_channel: NotificationChannel | None = None,
) -> None:
    publish_notify_user(
        firebase_uid=firebase_uid,
        title=title,
        body=body,
        deep_link=deep_link,
        baby_profile_id=baby_profile_id,
        notification_channel=(
            notification_channel.value if notification_channel else None
        ),
    )


def safe_enqueue_notify_user(
    firebase_uid: str,
    *,
    title: str,
    body: str,
    deep_link: str,
    baby_profile_id: uuid.UUID | None = None,
    notification_channel: NotificationChannel | None = None,
) -> None:
    """Publish notify_user without failing the HTTP request after DB commit."""
    try:
        enqueue_notify_user(
            firebase_uid,
            title=title,
            body=body,
            deep_link=deep_link,
            baby_profile_id=baby_profile_id,
            notification_channel=notification_channel,
        )
    except Exception:
        logger.exception(
            "notify_user_enqueue_failed firebase_uid=%s deep_link=%s",
            firebase_uid,
            deep_link,
        )
