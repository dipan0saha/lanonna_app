"""Baby hard-delete vs child-row INSERT races (#442)."""

from __future__ import annotations

import threading
import time
import uuid
from typing import Any

import psycopg
import pytest

from lanonna_api.config import settings
from lanonna_api.db import get_connection
from lanonna_api.repositories.pending_photos import create_pending_photo
from lanonna_api.repositories.users import resolve_app_user

pytestmark = [
    pytest.mark.integration,
    pytest.mark.filterwarnings("error::pytest.PytestUnhandledThreadExceptionWarning"),
]


def _user(tag: str) -> str:
    uid = f"child-race-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    return uid


def _sole_owned_baby(owner_uid: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Race Baby', 'expecting', %s)
            """,
            (baby_id, owner_uid),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships
            (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, owner_uid),
        )
    return baby_id


def _connect() -> psycopg.Connection[Any]:
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
    )


def test_create_pending_photo_waits_for_delete_then_not_found_not_fk():
    """Deterministic two-connection race: delete holds FOR UPDATE; upload waits."""
    owner = _user("photo")
    baby_id = _sole_owned_baby(owner)
    errors: list[BaseException] = []
    upload_error: LookupError | None = None

    def run_upload() -> None:
        nonlocal upload_error
        try:
            create_pending_photo(
                baby_id,
                owner,
                content_type="image/jpeg",
                byte_length=1024,
            )
        except LookupError as exc:
            upload_error = exc
        except BaseException as exc:
            errors.append(exc)

    holder = _connect()
    observer = _connect()
    observer.autocommit = True
    worker = threading.Thread(target=run_upload)
    try:
        holder.execute(
            "SELECT id FROM baby_profiles WHERE id = %s FOR UPDATE",
            (baby_id,),
        )
        worker.start()
        deadline = time.monotonic() + 10
        while True:
            waiting = observer.execute(
                """
                SELECT 1 FROM pg_stat_activity
                WHERE datname = current_database()
                  AND wait_event_type = 'Lock'
                  AND query ILIKE '%%FOR KEY SHARE%%'
                """
            ).fetchone()
            if waiting:
                break
            assert worker.is_alive(), "upload finished without waiting on baby lock"
            assert time.monotonic() < deadline, "upload never blocked on baby row lock"
            time.sleep(0.05)
        holder.execute("DELETE FROM baby_profiles WHERE id = %s", (baby_id,))
        holder.commit()
        worker.join(timeout=10)
        assert not worker.is_alive()
    finally:
        holder.close()
        observer.close()

    assert errors == []
    assert upload_error is not None
    assert "not found" in str(upload_error).lower()
    with get_connection() as conn:
        assert conn.execute(
            "SELECT COUNT(*)::int AS n FROM photos WHERE baby_profile_id = %s",
            (baby_id,),
        ).fetchone()["n"] == 0
