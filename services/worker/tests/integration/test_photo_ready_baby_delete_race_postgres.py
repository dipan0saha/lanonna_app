"""Worker photo-ready vs baby hard-delete lock order (#442)."""

from __future__ import annotations

import threading
import time
import uuid

import psycopg
import pytest

from lanonna_worker.db import get_connection, mark_photo_ready

pytestmark = pytest.mark.filterwarnings(
    "error::pytest.PytestUnhandledThreadExceptionWarning"
)

_OWNER = "ready-race-owner"


def _raw_connection(**kwargs) -> psycopg.Connection:
    from lanonna_worker.config import settings

    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
        dbname=settings.db_name,
        **kwargs,
    )


def _pending_photo() -> tuple[uuid.UUID, str]:
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    display_path = f"display/{photo_id}.webp"
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO app_users (firebase_uid) VALUES (%s) ON CONFLICT DO NOTHING",
            (_OWNER,),
        )
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Race', 'expecting', %s)
            """,
            (baby_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status,
                                display_path, purpose)
            VALUES (%s, %s, %s, 'pending', %s, 'gallery')
            """,
            (photo_id, baby_id, _OWNER, display_path),
        )
    return baby_id, display_path


def test_photo_ready_waits_on_baby_before_locking_photo_so_delete_never_deadlocks():
    """Delete holds the baby FOR UPDATE, then cascades into photos. The worker must
    wait on the baby before it UPDATEs the photo, or the two deadlock."""
    baby_id, display_path = _pending_photo()
    results: list[object] = []
    errors: list[BaseException] = []

    def run_ready() -> None:
        try:
            results.append(
                mark_photo_ready(
                    display_path=display_path,
                    thumb_path="thumbnails/x.jpg",
                    object_generation=None,
                    byte_length=10,
                )
            )
        except BaseException as exc:
            errors.append(exc)

    holder = _raw_connection()
    observer = _raw_connection(autocommit=True)
    worker = threading.Thread(target=run_ready)
    try:
        holder.execute(
            "SELECT id FROM baby_profiles WHERE id = %s FOR UPDATE", (baby_id,)
        )
        worker.start()
        deadline = time.monotonic() + 10
        while not observer.execute(
            """
            SELECT 1 FROM pg_stat_activity
            WHERE datname = current_database()
              AND wait_event_type = 'Lock'
              AND query ILIKE '%%baby_profiles%%FOR KEY SHARE%%'
            """
        ).fetchone():
            assert worker.is_alive(), "photo-ready finished without waiting on baby"
            assert time.monotonic() < deadline, "photo-ready never blocked on baby"
            time.sleep(0.05)
        # Cascade into photos: blocks forever (deadlock) if the worker had
        # already locked the photo row with its UPDATE.
        holder.execute("SET lock_timeout = '5s'")
        holder.execute("DELETE FROM baby_profiles WHERE id = %s", (baby_id,))
        holder.commit()
        worker.join(timeout=10)
        assert not worker.is_alive()
    finally:
        holder.close()
        observer.close()

    assert errors == []
    assert results == [None]
    with get_connection() as conn:
        assert (
            conn.execute(
                "SELECT COUNT(*)::int AS n FROM activity_events WHERE baby_profile_id = %s",
                (baby_id,),
            ).fetchone()["n"]
            == 0
        )
