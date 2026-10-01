from __future__ import annotations

import uuid
from typing import Any

from psycopg.types.json import Json

from lanonna_api.db import get_connection


def insert_activity_event(
    baby_profile_id: uuid.UUID,
    actor_firebase_uid: str | None,
    event_type: str,
    summary: str,
    payload: dict[str, Any] | None = None,
    conn=None,
) -> dict[str, Any]:
    event_id = uuid.uuid4()

    def _run(connection):
        row = connection.execute(
            """
            INSERT INTO activity_events (
                id, baby_profile_id, actor_firebase_uid,
                event_type, summary, payload
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, event_type, summary, created_at
            """,
            (
                event_id,
                baby_profile_id,
                actor_firebase_uid,
                event_type,
                summary,
                Json(payload) if payload is not None else None,
            ),
        ).fetchone()
        return dict(row) if row else None

    if conn is not None:
        return _run(conn)
    with get_connection() as connection:
        return _run(connection)


def list_recent_for_baby(
    baby_profile_id: uuid.UUID,
    limit: int = 10,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, event_type, summary, created_at
            FROM activity_events
            WHERE baby_profile_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, limit),
        ).fetchall()
    return [dict(row) for row in rows]


def count_name_suggestions(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM name_suggestions
            WHERE baby_profile_id = %s
            """,
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0
