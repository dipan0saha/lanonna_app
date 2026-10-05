from __future__ import annotations

import uuid
from typing import Any

from lanonna_activity_copy import (
    EVENT_PHOTO_COMMENT,
    EVENT_PHOTO_SQUISH,
    GALLERY_ACTIVITY_EVENT_TYPES,
    photo_comment_summary,
    photo_squish_summary,
)

__all__ = [
    "EVENT_PHOTO_SQUISH",
    "EVENT_PHOTO_COMMENT",
    "GALLERY_ACTIVITY_EVENT_TYPES",
    "photo_squish_summary",
    "photo_comment_summary",
    "photo_id_from_payload",
    "actor_name_from_row",
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


def actor_name_from_row(row: dict[str, Any]) -> str | None:
    name = row.get("actor_display_name")
    if name is None:
        return None
    text = str(name).strip()
    return text or None


def serialize_activity_item(row: dict[str, Any]) -> dict[str, Any]:
    created = row["created_at"]
    photo_id = photo_id_from_payload(row.get("payload"))
    actor = actor_name_from_row(row)
    return {
        "id": row["id"],
        "event_type": row["event_type"],
        "summary": row["summary"],
        "created_at": created.isoformat()
        if hasattr(created, "isoformat")
        else str(created),
        "actor_display_name": actor,
        "photo_id": str(photo_id) if photo_id else None,
    }
