from __future__ import annotations

import uuid
from typing import Any


def try_claim_delivery(conn: Any, delivery_key: str) -> bool:
    """Return True when this key is new (worker should process the message)."""
    if not delivery_key:
        return True
    row = conn.execute(
        """
        INSERT INTO worker_delivery_log (delivery_key)
        VALUES (%s)
        ON CONFLICT (delivery_key) DO NOTHING
        RETURNING delivery_key
        """,
        (delivery_key,),
    ).fetchone()
    return row is not None


def try_claim_photo_ready_notify(
    conn: Any,
    photo_id: uuid.UUID,
    object_generation: int | None,
) -> bool:
    """Return True when photo-ready fan-out notify has not run for this generation."""
    gen = int(object_generation) if object_generation is not None else 0
    row = conn.execute(
        """
        INSERT INTO photo_ready_notification_log (photo_id, object_generation)
        VALUES (%s, %s)
        ON CONFLICT (photo_id, object_generation) DO NOTHING
        RETURNING photo_id
        """,
        (photo_id, gen),
    ).fetchone()
    return row is not None


def resolve_delivery_key(
    payload: dict[str, Any],
    *,
    pubsub_message_id: str | None,
) -> str | None:
    explicit = payload.get("dedupe_key")
    if explicit:
        return str(explicit)
    if pubsub_message_id:
        return f"pubsub:{pubsub_message_id}"
    return None
