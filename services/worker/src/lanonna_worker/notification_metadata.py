"""Notification types (must match the DB check on notifications.notification_type)."""

from __future__ import annotations

from typing import Any

GENERIC = "generic"

NOTIFICATION_TYPES = frozenset(
    {"photo", "event", "registry", "fun", "comment", "squish", "digest", GENERIC}
)


def notification_type_from_payload(payload: dict[str, Any]) -> str:
    """Type from a publish payload; unknown or missing (older API) -> generic."""
    raw = str(payload.get("notification_type") or GENERIC)
    return raw if raw in NOTIFICATION_TYPES else GENERIC


def actor_uid_from_payload(payload: dict[str, Any]) -> str | None:
    raw = payload.get("actor_firebase_uid")
    return str(raw) if raw else None
