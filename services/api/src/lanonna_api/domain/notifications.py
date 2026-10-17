"""Publish structured notifications for the worker to deliver.

Callers say *what happened* (:class:`NotificationKind`), who did it, and the
display params; they never write copy. The worker derives the inbox icon
category, stores ``kind`` + ``params`` for the app to render from ARB, and
renders the English push text (``lanonna_activity_copy.notifications``).
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any, Literal

from lanonna_activity_copy import NotificationKind

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
    kind: NotificationKind
    deep_link: str
    actor_firebase_uid: str | None
    params: dict[str, Any] = field(default_factory=dict)
    recipient_mode: RecipientMode = "baby_members"
    exclude_firebase_uid: str | None = None
    firebase_uids: tuple[str, ...] = ()
    notification_channel: NotificationChannel | None = None


@dataclass(frozen=True)
class NotifyUserSpec:
    firebase_uid: str
    kind: NotificationKind
    deep_link: str
    actor_firebase_uid: str | None
    params: dict[str, Any] = field(default_factory=dict)
    baby_profile_id: uuid.UUID | None = None
    notification_channel: NotificationChannel | None = None


def _channel(value: NotificationChannel | None) -> str | None:
    return value.value if value else None


def enqueue_fan_out(spec: FanOutSpec) -> None:
    publish_notify_fan_out(
        baby_profile_id=spec.baby_profile_id,
        kind=spec.kind.value,
        params=dict(spec.params),
        deep_link=spec.deep_link,
        recipient_mode=spec.recipient_mode,
        exclude_firebase_uid=spec.exclude_firebase_uid,
        firebase_uids=list(spec.firebase_uids),
        notification_channel=_channel(spec.notification_channel),
        actor_firebase_uid=spec.actor_firebase_uid,
    )


def safe_enqueue_fan_out(spec: FanOutSpec) -> None:
    """Publish notify fan-out without failing the HTTP request after DB commit."""
    try:
        enqueue_fan_out(spec)
    except Exception:
        logger.exception(
            "notify_fan_out_enqueue_failed baby_profile_id=%s kind=%s",
            spec.baby_profile_id,
            spec.kind,
        )


def enqueue_notify_user(spec: NotifyUserSpec) -> None:
    publish_notify_user(
        firebase_uid=spec.firebase_uid,
        kind=spec.kind.value,
        params=dict(spec.params),
        deep_link=spec.deep_link,
        baby_profile_id=spec.baby_profile_id,
        notification_channel=_channel(spec.notification_channel),
        actor_firebase_uid=spec.actor_firebase_uid,
    )


def safe_enqueue_notify_user(spec: NotifyUserSpec) -> None:
    """Publish notify_user without failing the HTTP request after DB commit."""
    try:
        enqueue_notify_user(spec)
    except Exception:
        logger.exception(
            "notify_user_enqueue_failed firebase_uid=%s kind=%s",
            spec.firebase_uid,
            spec.kind,
        )
