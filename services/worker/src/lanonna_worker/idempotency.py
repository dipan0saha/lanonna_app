from __future__ import annotations

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
