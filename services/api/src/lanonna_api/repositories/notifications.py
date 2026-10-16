from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def list_notifications_for_user(
    firebase_uid: str,
    *,
    limit: int = 50,
    offset: int = 0,
    unread_only: bool = False,
) -> list[dict[str, Any]]:
    clause = "AND read_at IS NULL" if unread_only else ""
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                id, baby_profile_id, title, body, deep_link, read_at, created_at,
                notification_type, actor_firebase_uid, actor_display_name
            FROM notifications
            WHERE firebase_uid = %s
            {clause}
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
            """,
            (firebase_uid, limit, offset),
        ).fetchall()
    return [dict(row) for row in rows]


def count_unread_notifications(firebase_uid: str) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS n
            FROM notifications
            WHERE firebase_uid = %s AND read_at IS NULL
            """,
            (firebase_uid,),
        ).fetchone()
    return int(row["n"]) if row else 0


def mark_notification_read(notification_id: uuid.UUID, firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE notifications
            SET read_at = now()
            WHERE id = %s AND firebase_uid = %s AND read_at IS NULL
            RETURNING id
            """,
            (notification_id, firebase_uid),
        ).fetchone()
    return row is not None


def mark_all_notifications_read(firebase_uid: str) -> int:
    """Mark every unread inbox row read for this user; returns rows updated."""
    with get_connection() as conn:
        rows = conn.execute(
            """
            UPDATE notifications
            SET read_at = now()
            WHERE firebase_uid = %s AND read_at IS NULL
            RETURNING id
            """,
            (firebase_uid,),
        ).fetchall()
    return len(rows)
