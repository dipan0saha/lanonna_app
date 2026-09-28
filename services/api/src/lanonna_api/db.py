from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row

from lanonna_api.config import settings


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


def upsert_app_user(firebase_uid: str, email: str | None) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO app_users (firebase_uid, email)
            VALUES (%s, %s)
            ON CONFLICT (firebase_uid) DO UPDATE
              SET email = EXCLUDED.email,
                  updated_at = now()
            RETURNING firebase_uid, email, created_at, updated_at
            """,
            (firebase_uid, email),
        ).fetchone()
    if row is None:
        raise RuntimeError("upsert_app_user returned no row")
    return dict(row)
