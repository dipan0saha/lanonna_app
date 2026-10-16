"""Structured notification type shared by API publish paths and inbox rows.

The API publishes ``notification_type`` and ``actor_firebase_uid``; the worker
resolves the actor display name when it writes the inbox row (one lookup, one
place). Values must match the DB check on ``notifications.notification_type``.
"""

from __future__ import annotations

from enum import StrEnum


class NotificationType(StrEnum):
    PHOTO = "photo"
    EVENT = "event"
    REGISTRY = "registry"
    FUN = "fun"
    COMMENT = "comment"
    SQUISH = "squish"
    DIGEST = "digest"
    GENERIC = "generic"
