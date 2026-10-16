"""Migration 037: actor uid backfill from structured sources only."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import psycopg
import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_BACKFILL_SQL = (
    Path(__file__).resolve().parents[4]
    / "infra"
    / "db"
    / "migrations"
    / "037_notification_actor_backfill.sql"
)


def _run_actor_backfill_migration() -> None:
    with get_connection() as conn:
        with psycopg.ClientCursor(conn) as cur:
            cur.execute(_BACKFILL_SQL.read_text())
        conn.commit()


def _insert_notification(
    *,
    recipient: str,
    baby_id: uuid.UUID,
    notification_type: str,
    title: str,
    deep_link: str,
    created_at: datetime,
    actor: str | None = None,
) -> uuid.UUID:
    nid = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO notifications (
                id, firebase_uid, baby_profile_id, title, body, deep_link,
                notification_type, actor_firebase_uid, created_at
            )
            VALUES (%s, %s, %s, %s, 'B', %s, %s, %s, %s)
            """,
            (nid, recipient, baby_id, title, deep_link, notification_type, actor, created_at),
        )
    return nid


def _actor(nid: uuid.UUID) -> str | None:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT actor_firebase_uid FROM notifications WHERE id = %s", (nid,)
        ).fetchone()
    return row["actor_firebase_uid"]


def _seed_photo(owner: str, members: list[str]) -> tuple[uuid.UUID, uuid.UUID]:
    for uid in [owner, *members]:
        resolve_app_user(uid, f"{uid}@example.com")
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Test', 'expecting', %s)
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, owner),
        )
        for uid in members:
            conn.execute(
                """
                INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
                VALUES (%s, %s, 'follower', 'invite')
                """,
                (baby_id, uid),
            )
        conn.execute(
            """
            INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status)
            VALUES (%s, %s, %s, 'ready')
            """,
            (photo_id, baby_id, owner),
        )
    return baby_id, photo_id


def _squish(photo_id: uuid.UUID, uid: str, at: datetime) -> None:
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO photo_squishes (photo_id, firebase_uid, created_at) VALUES (%s, %s, %s)",
            (photo_id, uid, at),
        )


_AT = datetime(2026, 5, 1, 12, 0, tzinfo=timezone.utc)


def test_backfills_single_squisher(postgres_database):
    baby_id, photo_id = _seed_photo("bf-owner-1", ["bf-squisher-1"])
    _squish(photo_id, "bf-squisher-1", _AT)
    nid = _insert_notification(
        recipient="bf-owner-1",
        baby_id=baby_id,
        notification_type="squish",
        title="New squish",
        deep_link=f"/gallery/photo/{photo_id}",
        created_at=_AT + timedelta(seconds=1),
    )
    _run_actor_backfill_migration()
    assert _actor(nid) == "bf-squisher-1"


def test_ambiguous_candidates_stay_null(postgres_database):
    baby_id, photo_id = _seed_photo("bf-owner-2", ["bf-a", "bf-b"])
    _squish(photo_id, "bf-a", _AT)
    _squish(photo_id, "bf-b", _AT + timedelta(seconds=1))
    nid = _insert_notification(
        recipient="bf-owner-2",
        baby_id=baby_id,
        notification_type="squish",
        title="New squish",
        deep_link=f"/gallery/photo/{photo_id}",
        created_at=_AT + timedelta(seconds=2),
    )
    _run_actor_backfill_migration()
    assert _actor(nid) is None


def test_source_outside_window_and_existing_actor_untouched(postgres_database):
    baby_id, photo_id = _seed_photo("bf-owner-3", ["bf-old", "bf-kept"])
    _squish(photo_id, "bf-old", _AT - timedelta(hours=1))
    stale = _insert_notification(
        recipient="bf-owner-3",
        baby_id=baby_id,
        notification_type="squish",
        title="New squish",
        deep_link=f"/gallery/photo/{photo_id}",
        created_at=_AT,
    )
    kept = _insert_notification(
        recipient="bf-owner-3",
        baby_id=baby_id,
        notification_type="squish",
        title="New squish",
        deep_link=f"/gallery/photo/{photo_id}",
        created_at=_AT - timedelta(hours=1),
        actor="bf-kept",
    )
    _run_actor_backfill_migration()
    _run_actor_backfill_migration()
    assert _actor(stale) is None
    assert _actor(kept) == "bf-kept"
