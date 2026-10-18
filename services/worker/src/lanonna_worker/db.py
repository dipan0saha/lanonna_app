"""Postgres access for the worker: one connection pool per process.

``get_connection()`` keeps its contract (commit on success, rollback on an
exception, ``DatabaseNotConfiguredError`` without credentials) but borrows a
pooled connection instead of opening a new one per call. The pool is opened
in the FastAPI lifespan and closed on shutdown; tests and scripts open it
lazily on first use.
"""

from __future__ import annotations

import threading
import uuid
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Json
from psycopg_pool import ConnectionPool

from lanonna_activity_copy import ActivityEventType, activity_summary, caption_params
from lanonna_worker.config import settings

_pool: ConnectionPool | None = None
_pool_lock = threading.Lock()


class DatabaseNotConfiguredError(RuntimeError):
    """Raised when the worker runs without database credentials (e.g. local thumbnail-only runs)."""


def _require_configured() -> None:
    if not settings.db_password:
        raise DatabaseNotConfiguredError("Database is not configured (missing DB_PASSWORD).")


def _connect_kwargs() -> dict[str, Any]:
    if settings.cloud_sql_connection_name:
        return {
            "host": f"/cloudsql/{settings.cloud_sql_connection_name}",
            "user": settings.db_user,
            "dbname": settings.db_name,
            "password": settings.db_password,
        }
    return {
        "host": settings.db_host,
        "port": settings.db_port,
        "user": settings.db_user,
        "dbname": settings.db_name,
        "password": settings.db_password,
    }


def open_pool() -> ConnectionPool:
    """Create and open the process pool (idempotent, does not wait for connections)."""
    global _pool
    _require_configured()
    with _pool_lock:
        if _pool is None:
            _pool = ConnectionPool(
                kwargs={**_connect_kwargs(), "row_factory": dict_row},
                min_size=settings.db_pool_min_size,
                max_size=settings.db_pool_max_size,
                timeout=settings.db_pool_timeout_seconds,
                max_idle=settings.db_pool_max_idle_seconds,
                check=ConnectionPool.check_connection,
                name="lanonna-worker",
                open=True,
            )
        return _pool


def close_pool() -> None:
    global _pool
    with _pool_lock:
        pool, _pool = _pool, None
    if pool is not None:
        pool.close()


@contextmanager
def get_connection() -> Iterator[psycopg.Connection[Any]]:
    _require_configured()
    # Commits when the block succeeds, rolls back on an exception.
    with (_pool or open_pool()).connection() as conn:
        yield conn


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
            RETURNING id, baby_profile_id, uploader_firebase_uid, caption, purpose
            """,
            (thumb_path, object_generation, byte_length, display_path),
        ).fetchone()
        if row is not None and row.get("purpose") != "event_cover":
            # Structured feed row (lanonna_activity_copy.activity): the app renders
            # it from ARB; the actor's name is resolved at read time, never from
            # an email (#7). ``summary`` is English diagnostic copy only.
            actor_row = conn.execute(
                """
                SELECT NULLIF(TRIM(display_name), '') AS name
                FROM app_users
                WHERE firebase_uid = %s
                """,
                (row["uploader_firebase_uid"],),
            ).fetchone()
            params = caption_params(row.get("caption"))
            summary = activity_summary(
                ActivityEventType.PHOTO_SHARED,
                params,
                actor=(actor_row and actor_row["name"]) or "Someone",
            )
            conn.execute(
                """
                INSERT INTO activity_events (
                    id, baby_profile_id, actor_firebase_uid,
                    event_type, summary, params, payload
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    uuid.uuid4(),
                    row["baby_profile_id"],
                    row["uploader_firebase_uid"],
                    ActivityEventType.PHOTO_SHARED.value,
                    summary,
                    Json(params),
                    Json({"photo_id": str(row["id"])}),
                ),
            )
        if row is not None:
            return dict(row)
    return None


def get_ready_photo_by_display_path(display_path: str) -> dict[str, Any] | None:
    """Ready photo row for display path (used when mark_photo_ready is idempotent)."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, baby_profile_id, uploader_firebase_uid, display_object_generation, purpose
            FROM photos
            WHERE display_path = %s
              AND status = 'ready'
            LIMIT 1
            """,
            (display_path,),
        ).fetchone()
    return dict(row) if row else None
