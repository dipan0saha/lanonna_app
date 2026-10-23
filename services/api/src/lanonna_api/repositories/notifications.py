from __future__ import annotations

import uuid
from datetime import datetime
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
                notification_type, notification_kind, params,
                actor_firebase_uid, actor_display_name
            FROM notifications
            WHERE firebase_uid = %s
            {clause}
            ORDER BY created_at DESC, id DESC
            LIMIT %s OFFSET %s
            """,
            (firebase_uid, limit, offset),
        ).fetchall()
    return [dict(row) for row in rows]


def list_notifications_for_user_keyset(
    firebase_uid: str,
    *,
    limit: int = 50,
    cursor_created_at: datetime | None = None,
    cursor_id: uuid.UUID | None = None,
    unread_only: bool = False,
) -> list[dict[str, Any]]:
    """Newest-first inbox page; optional cursor is the last row of the prior page."""
    assert (cursor_created_at is None) == (cursor_id is None)
    clause = "AND read_at IS NULL" if unread_only else ""
    cursor_clause = ""
    params: list[Any] = [firebase_uid]
    if cursor_created_at is not None and cursor_id is not None:
        cursor_clause = "AND (created_at, id) < (%s, %s)"
        params.extend([cursor_created_at, cursor_id])
    params.append(limit)
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                id, baby_profile_id, title, body, deep_link, read_at, created_at,
                notification_type, notification_kind, params,
                actor_firebase_uid, actor_display_name
            FROM notifications
            WHERE firebase_uid = %s
            {clause}
            {cursor_clause}
            ORDER BY created_at DESC, id DESC
            LIMIT %s
            """,
            tuple(params),
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
