"""Activity feed rows as the API returns them.

Each item is structured: ``event_type``, ``params`` (display values captured
when it happened) and the people involved, resolved at read time. The app
renders the sentence from ARB; ``summary`` is the English diagnostic copy and
is only shown by an app build that does not know the type yet.
"""

from __future__ import annotations

import uuid
from typing import Any

from lanonna_activity_copy import ACTOR_HIDDEN_EVENT_TYPES

__all__ = [
    "photo_id_from_payload",
    "serialize_activity_item",
]


def photo_id_from_payload(payload: Any) -> uuid.UUID | None:
    if not payload or not isinstance(payload, dict):
        return None
    raw = payload.get("photo_id")
    if raw is None:
        return None
    try:
        return uuid.UUID(str(raw))
    except (ValueError, TypeError):
        return None


def _trimmed(value: Any) -> str | None:
    text = str(value).strip() if value is not None else ""
    return text or None


def serialize_activity_item(row: dict[str, Any]) -> dict[str, Any]:
    created = row["created_at"]
    photo_id = photo_id_from_payload(row.get("payload"))
    actor_hidden = row["event_type"] in ACTOR_HIDDEN_EVENT_TYPES
    params = row.get("params")
    return {
        "id": row["id"],
        "event_type": row["event_type"],
        "params": dict(params) if isinstance(params, dict) else {},
        "summary": row["summary"],
        "created_at": created.isoformat()
        if hasattr(created, "isoformat")
        else str(created),
        "actor_display_name": None
        if actor_hidden
        else _trimmed(row.get("actor_display_name")),
        "target_display_name": _trimmed(row.get("target_display_name")),
        "photo_id": str(photo_id) if photo_id else None,
    }
