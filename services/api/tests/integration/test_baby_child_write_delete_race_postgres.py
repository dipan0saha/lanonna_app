"""Baby hard-delete vs child-row INSERT races (#442).

Each writer must wait on the baby row lock that delete holds, then fail with a
clean ``NotFoundError`` (HTTP 404) instead of a foreign-key ``IntegrityError``.
"""

from __future__ import annotations

import threading
import time
import uuid
from collections.abc import Callable
from typing import Any

import psycopg
import pytest

from lanonna_activity_copy import ActivityEventType
from lanonna_api.config import settings
from lanonna_api.db import get_connection
from lanonna_api.domain.errors import NotFoundError
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.repositories.pending_photos import create_pending_photo
from lanonna_api.repositories.photos import insert_photo_comment
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


def _ready_photo(baby_id: uuid.UUID, owner_uid: str) -> uuid.UUID:
    photo_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status,
                                display_path, purpose)
            VALUES (%s, %s, %s, 'ready', %s, 'gallery')
            """,
            (photo_id, baby_id, owner_uid, f"display/{photo_id}.webp"),
        )
    return photo_id


def _connect() -> psycopg.Connection[Any]:
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
    )


def _race_write_against_delete(
    baby_id: uuid.UUID, write: Callable[[], Any], *, delete_first: bool
) -> None:
    """An uncommitted baby delete is in flight; the write must block, then 404.

    ``delete_first=False``: delete holds the baby FOR UPDATE (as
    ``delete_baby_profile`` does) and only issues the DELETE once the write waits.
    ``delete_first=True``: the DELETE (and its cascades) already ran, uncommitted.
    """
    errors: list[BaseException] = []
    not_found: list[NotFoundError] = []

    def run_write() -> None:
        try:
            write()
        except NotFoundError as exc:
            not_found.append(exc)
        except BaseException as exc:
            errors.append(exc)

    holder = _connect()
    observer = _connect()
    observer.autocommit = True
    worker = threading.Thread(target=run_write)
    try:
        if delete_first:
            holder.execute("DELETE FROM baby_profiles WHERE id = %s", (baby_id,))
        else:
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
                  AND pid <> %s
                """,
                (holder.info.backend_pid,),
            ).fetchone()
            if waiting:
                break
            assert worker.is_alive(), "write finished without waiting on baby lock"
            assert time.monotonic() < deadline, "write never blocked on baby row lock"
            time.sleep(0.05)
        if not delete_first:
            holder.execute("DELETE FROM baby_profiles WHERE id = %s", (baby_id,))
        holder.commit()
        worker.join(timeout=10)
        assert not worker.is_alive()
    finally:
        holder.close()
        observer.close()

    # Pre-fix code also blocks (on the FK check) but then raises
    # ForeignKeyViolation, which the API surfaced as a 500.
    assert errors == []
    assert len(not_found) == 1
    assert not_found[0].status_code == 404
    assert "not found" in str(not_found[0]).lower()


def _count(table: str, column: str, value: uuid.UUID) -> int:
    with get_connection() as conn:
        return conn.execute(
            f"SELECT COUNT(*)::int AS n FROM {table} WHERE {column} = %s",
            (value,),
        ).fetchone()["n"]


@pytest.mark.parametrize("delete_first", [False, True])
def test_create_pending_photo_waits_for_delete_then_not_found_not_fk(delete_first: bool):
    owner = _user("photo")
    baby_id = _sole_owned_baby(owner)
    _race_write_against_delete(
        baby_id,
        lambda: create_pending_photo(
            baby_id, owner, content_type="image/jpeg", byte_length=1024
        ),
        delete_first=delete_first,
    )
    assert _count("photos", "baby_profile_id", baby_id) == 0


@pytest.mark.parametrize("delete_first", [False, True])
def test_activity_event_waits_for_delete_then_not_found_not_fk(delete_first: bool):
    owner = _user("feed")
    baby_id = _sole_owned_baby(owner)
    _race_write_against_delete(
        baby_id,
        lambda: insert_activity_event(baby_id, owner, ActivityEventType.MEMBER_LEFT),
        delete_first=delete_first,
    )
    assert _count("activity_events", "baby_profile_id", baby_id) == 0


@pytest.mark.parametrize("delete_first", [False, True])
def test_photo_comment_waits_for_delete_then_not_found_not_fk(delete_first: bool):
    """Grandchild row: FK is to the photo, which the baby delete cascades away."""
    owner = _user("comment")
    baby_id = _sole_owned_baby(owner)
    photo_id = _ready_photo(baby_id, owner)
    _race_write_against_delete(
        baby_id,
        lambda: insert_photo_comment(photo_id, owner, "hello"),
        delete_first=delete_first,
    )
    assert _count("photo_comments", "photo_id", photo_id) == 0
