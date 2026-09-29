from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row

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
) -> bool:
    """Idempotent: returns False if this generation was already processed."""
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
                return False

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
            RETURNING id
            """,
            (thumb_path, object_generation, byte_length, display_path),
        ).fetchone()
    return row is not None
