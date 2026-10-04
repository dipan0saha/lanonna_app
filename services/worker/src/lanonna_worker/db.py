from __future__ import annotations

import uuid
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Json

from lanonna_worker.config import settings


@contextmanager
def get_connection() -> Iterator[psycopg.Connection[Any]]:
    if not settings.db_password:
        raise RuntimeError("Database is not configured (missing DB_PASSWORD).")
    if settings.cloud_sql_connection_name:
        host = f"/cloudsql/{settings.cloud_sql_connection_name}"
        conn = psycopg.connect(
            host=host,
            user=settings.db_user,
            dbname=settings.db_name,
            password=settings.db_password,
            row_factory=dict_row,
        )
    else:
        conn = psycopg.connect(
            host=settings.db_host,
            port=settings.db_port,
            user=settings.db_user,
            dbname=settings.db_name,
            password=settings.db_password,
            row_factory=dict_row,
        )
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def mark_photo_ready(
    display_path: str,
    thumb_path: str,
    object_generation: int | None,
    byte_length: int | None,
) -> dict[str, Any] | None:
    """Idempotent: returns photo row dict when newly marked ready, else None."""
    with get_connection() as conn:
        if object_generation is not None:
            existing = conn.execute(
                """
                SELECT id FROM photos
                WHERE display_object_generation = %s
                """,
                (object_generation,),
            ).fetchone()
            if existing is not None:
                return None

        row = conn.execute(
            """
            UPDATE photos
            SET status = 'ready',
                thumb_path = %s,
                display_object_generation = COALESCE(%s, display_object_generation),
                byte_length = COALESCE(%s, byte_length),
                updated_at = now()
            WHERE display_path = %s
              AND status = 'pending'
            RETURNING id, baby_profile_id, uploader_firebase_uid
            """,
            (thumb_path, object_generation, byte_length, display_path),
        ).fetchone()
        if row is not None:
            conn.execute(
                """
                INSERT INTO activity_events (
                    id, baby_profile_id, actor_firebase_uid,
                    event_type, summary, payload
                )
                VALUES (%s, %s, %s, 'photo_shared', 'A new photo was shared', %s)
                """,
                (
                    uuid.uuid4(),
                    row["baby_profile_id"],
                    row["uploader_firebase_uid"],
                    Json({"photo_id": str(row["id"])}),
                ),
            )
            return dict(row)
    return None


def get_ready_photo_by_display_path(display_path: str) -> dict[str, Any] | None:
    """Ready photo row for display path (used when mark_photo_ready is idempotent)."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, baby_profile_id, uploader_firebase_uid, display_object_generation
            FROM photos
            WHERE display_path = %s
              AND status = 'ready'
            LIMIT 1
            """,
            (display_path,),
        ).fetchone()
    return dict(row) if row else None
