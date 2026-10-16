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
    Path(__file__).resolve().parents[3]
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
    deep_link: str,
    created_at: datetime,
) -> uuid.UUID:
    nid = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO notifications (
                id, firebase_uid, baby_profile_id, title, body, deep_link,
                notification_type, actor_firebase_uid, created_at
            )
            VALUES (%s, %s, %s, 'T', 'B', %s, %s, NULL, %s)
            """,
            (nid, recipient, baby_id, deep_link, notification_type, created_at),
        )
    return nid


def test_migration_backfills_squish_actor_from_photo_squish_row(postgres_database):
    owner = "actor-backfill-owner"
    squisher = "actor-backfill-squisher"
    resolve_app_user(owner, "owner@example.com")
    resolve_app_user(squisher, "squisher@example.com")
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    squish_at = datetime(2026, 5, 1, 12, 0, tzinfo=timezone.utc)
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
            VALUES (%s, %s, 'owner', 'created'), (%s, %s, 'follower', 'invite')
            """,
            (baby_id, owner, baby_id, squisher),
        )
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status, created_at
            )
            VALUES (%s, %s, %s, 'ready', %s)
            """,
            (photo_id, baby_id, owner, squish_at),
        )
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid, created_at)
            VALUES (%s, %s, %s)
            """,
            (photo_id, squisher, squish_at),
        )
    _insert_notification(
        recipient=owner,
        baby_id=baby_id,
        notification_type="squish",
        deep_link=f"/gallery/photo/{photo_id}",
        created_at=squish_at + timedelta(seconds=1),
    )
    _run_actor_backfill_migration()
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT actor_firebase_uid FROM notifications
            WHERE firebase_uid = %s AND deep_link = %s
            """,
            (owner, f"/gallery/photo/{photo_id}"),
        ).fetchone()
    assert row is not None
    assert row["actor_firebase_uid"] == squisher
