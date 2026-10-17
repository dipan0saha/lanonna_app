from __future__ import annotations

import uuid
from collections.abc import Sequence
from typing import Any

from lanonna_activity_copy import ActivityEventType, activity_summary
from psycopg.types.json import Json

from lanonna_api.db import get_connection


def _display_name(connection: Any, firebase_uid: str | None) -> str | None:
    if not firebase_uid:
        return None
    row = connection.execute(
        "SELECT NULLIF(TRIM(display_name), '') AS name FROM app_users WHERE firebase_uid = %s",
        (firebase_uid,),
    ).fetchone()
    return row["name"] if row else None


def insert_activity_event(
    baby_profile_id: uuid.UUID,
    actor_firebase_uid: str | None,
    event_type: ActivityEventType,
    params: dict[str, Any] | None = None,
    payload: dict[str, Any] | None = None,
    conn=None,
) -> dict[str, Any]:
    """Record a structured feed event.

    ``params`` are display values for the app's ARB sentence (see
    ``lanonna_activity_copy.activity``); ``payload`` holds references such as
    ``photo_id``. ``summary`` is filled with the English diagnostic sentence.
    """
    event_id = uuid.uuid4()
    display_params = params or {}

    def _run(connection):
        target_uid = (payload or {}).get("target_firebase_uid")
        summary = activity_summary(
            event_type,
            display_params,
            actor=_display_name(connection, actor_firebase_uid) or "Someone",
            target=_display_name(connection, target_uid) or "a member",
        )
        row = connection.execute(
            """
            INSERT INTO activity_events (
                id, baby_profile_id, actor_firebase_uid,
                event_type, summary, params, payload
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id, event_type, summary, params, created_at
            """,
            (
                event_id,
                baby_profile_id,
                actor_firebase_uid,
                ActivityEventType(event_type).value,
                summary,
                Json(display_params),
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
    offset: int = 0,
    event_types: Sequence[str] | None = None,
) -> list[dict[str, Any]]:
    """Newest feed rows with the actor's and target's current display names.

    Names are NULL when the person has none; the app applies its fallback.
    """
    type_clause = "AND e.event_type = ANY(%s)" if event_types else ""
    type_params: tuple[Any, ...] = (list(event_types),) if event_types else ()
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                e.id,
                e.event_type,
                e.summary,
                e.params,
                e.created_at,
                e.payload,
                e.actor_firebase_uid,
                NULLIF(TRIM(u.display_name), '') AS actor_display_name,
                NULLIF(TRIM(t.display_name), '') AS target_display_name
            FROM activity_events e
            LEFT JOIN app_users u ON u.firebase_uid = e.actor_firebase_uid
            LEFT JOIN app_users t ON t.firebase_uid = e.payload->>'target_firebase_uid'
            WHERE e.baby_profile_id = %s
              {type_clause}
            ORDER BY e.created_at DESC, e.id DESC
            LIMIT %s OFFSET %s
            """,
            (baby_profile_id, *type_params, limit, offset),
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
