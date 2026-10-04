from __future__ import annotations

import uuid
from typing import Any

EVENT_PHOTO_SHARED = "photo_shared"
EVENT_PHOTO_SQUISH = "photo_squish"
EVENT_PHOTO_COMMENT = "photo_comment"

GALLERY_ACTIVITY_EVENT_TYPES: frozenset[str] = frozenset(
    {EVENT_PHOTO_SQUISH, EVENT_PHOTO_COMMENT}
)


def _truncate_caption(caption: str | None, max_len: int = 60) -> str:
    text = (caption or "").strip()
    if not text:
        return "a photo"
    if len(text) <= max_len:
        return text
    return f"{text[: max_len - 1].rstrip()}…"


def photo_shared_summary(actor: str, caption: str | None) -> str:
    label = _truncate_caption(caption)
    if caption and caption.strip():
        return f'{actor} added "{label}"'
    return f"{actor} shared a photo"


def photo_squish_summary(actor: str, caption: str | None) -> str:
    label = _truncate_caption(caption)
    return f'{actor} squished "{label}"'


def photo_comment_summary(actor: str, caption: str | None) -> str:
    label = _truncate_caption(caption)
    return f'{actor} commented on "{label}"'


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
