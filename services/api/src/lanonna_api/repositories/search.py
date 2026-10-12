from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def search_photos(
    baby_profile_id: uuid.UUID,
    pattern: str,
    limit: int,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT p.id, p.caption, p.thumb_path
            FROM photos p
            WHERE p.baby_profile_id = %s
              AND p.status = 'ready'
              AND p.caption ILIKE %s ESCAPE '\'
            ORDER BY p.created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, pattern, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def search_events(
    baby_profile_id: uuid.UUID,
    pattern: str,
    limit: int,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, title, starts_at
            FROM events
            WHERE baby_profile_id = %s
              AND (
                title ILIKE %s ESCAPE '\'
                OR COALESCE(location, '') ILIKE %s ESCAPE '\'
                OR COALESCE(description, '') ILIKE %s ESCAPE '\'
              )
            ORDER BY starts_at ASC
            LIMIT %s
            """,
            (baby_profile_id, pattern, pattern, pattern, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def search_registry_items(
    baby_profile_id: uuid.UUID,
    pattern: str,
    limit: int,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, name
            FROM registry_items
            WHERE baby_profile_id = %s
              AND (
                name ILIKE %s ESCAPE '\'
                OR COALESCE(description, '') ILIKE %s ESCAPE '\'
              )
            ORDER BY priority DESC, created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, pattern, pattern, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def search_name_suggestions(
    baby_profile_id: uuid.UUID,
    pattern: str,
    limit: int,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, suggested_name AS name
            FROM name_suggestions
            WHERE baby_profile_id = %s
              AND suggested_name ILIKE %s ESCAPE '\'
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, pattern, limit),
        ).fetchall()
    return [dict(r) for r in rows]
