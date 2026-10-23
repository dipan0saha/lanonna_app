"""Stale event-cover purge against real Postgres (GCS mocked) (#414)."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import psycopg
import pytest

from lanonna_worker.db import get_connection
from lanonna_worker.event_cover_cleanup import (
    EventCoverPurgeIncomplete,
    purge_stale_unreferenced_event_covers,
)
from lanonna_worker.gcs_delete import GcsDeleteError

_OWNER = "cover-owner"


def _baby() -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO app_users (firebase_uid) VALUES (%s) ON CONFLICT DO NOTHING",
            (_OWNER,),
        )
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Parker', 'expecting', %s)
            """,
            (baby_id, _OWNER),
        )
    return baby_id


def _photo(baby_id: uuid.UUID, *, purpose: str = "event_cover", age: str = "2 days") -> uuid.UUID:
    photo_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status,
                display_path, purpose, created_at
            )
            VALUES (%s, %s, %s, 'ready', %s, %s, now() - %s::interval)
            """,
            (photo_id, baby_id, _OWNER, f"display/{photo_id}.webp", purpose, age),
        )
    return photo_id


def _event(baby_id: uuid.UUID, cover_id: uuid.UUID) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO events (baby_profile_id, created_by_firebase_uid, title,
                                starts_at, cover_photo_id)
            VALUES (%s, %s, 'Shower', %s, %s)
            """,
            (baby_id, _OWNER, datetime(2027, 1, 1, tzinfo=timezone.utc), cover_id),
        )


def _exists(photo_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        return (
            conn.execute("SELECT 1 FROM photos WHERE id = %s", (photo_id,)).fetchone()
            is not None
        )


def _raw_connection() -> psycopg.Connection:
    from lanonna_worker.config import settings

    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
        dbname=settings.db_name,
    )


def test_purges_only_stale_unattached_covers():
    baby = _baby()
    stale = _photo(baby)
    attached = _photo(baby)
    _event(baby, attached)
    announced = _photo(baby)
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO birth_announcements (baby_profile_id, created_by_firebase_uid,
                                             first_name, photo_id)
            VALUES (%s, %s, 'Parker', %s)
            """,
            (baby, _OWNER, announced),
        )
    fresh = _photo(baby, age="1 hour")
    gallery = _photo(baby, purpose="gallery")

    with patch(
        "lanonna_worker.event_cover_cleanup.delete_photo_paths", return_value=2
    ) as delete:
        assert purge_stale_unreferenced_event_covers() == 1

    delete.assert_called_once_with(f"display/{stale}.webp", None)
    assert not _exists(stale)
    for kept in (attached, announced, fresh, gallery):
        assert _exists(kept)


def test_gcs_failure_keeps_the_row_for_the_next_run():
    baby = _baby()
    stale = _photo(baby)
    with patch(
        "lanonna_worker.event_cover_cleanup.delete_photo_paths",
        side_effect=GcsDeleteError("boom"),
    ):
        with pytest.raises(EventCoverPurgeIncomplete):
            purge_stale_unreferenced_event_covers()
    assert _exists(stale)

    with patch("lanonna_worker.event_cover_cleanup.delete_photo_paths", return_value=0):
        assert purge_stale_unreferenced_event_covers() == 1
    assert not _exists(stale)


def test_cover_being_attached_is_skipped_and_kept():
    baby = _baby()
    cover = _photo(baby)
    # An attach in flight: its FK check holds a key-share lock on the photo.
    attach = _raw_connection()
    try:
        attach.execute(
            """
            INSERT INTO events (baby_profile_id, created_by_firebase_uid, title,
                                starts_at, cover_photo_id)
            VALUES (%s, %s, 'Shower', %s, %s)
            """,
            (baby, _OWNER, datetime(2027, 1, 1, tzinfo=timezone.utc), cover),
        )
        with patch(
            "lanonna_worker.event_cover_cleanup.delete_photo_paths", return_value=2
        ) as delete:
            assert purge_stale_unreferenced_event_covers() == 0
        delete.assert_not_called()
        attach.commit()
    finally:
        attach.close()

    assert _exists(cover)
    with get_connection() as conn:
        row = conn.execute(
            "SELECT cover_photo_id FROM events WHERE baby_profile_id = %s", (baby,)
        ).fetchone()
    assert row["cover_photo_id"] == cover
