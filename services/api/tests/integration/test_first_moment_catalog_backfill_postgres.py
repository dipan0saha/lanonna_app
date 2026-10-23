"""Migration 047 links pre-#412 first-moment seeds to catalog rows."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path

import psycopg
import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_MIGRATION = (
    Path(__file__).resolve().parents[4]
    / "infra/db/migrations/047_first_moment_catalog_ids_backfill.sql"
)
_OWNER = "owner-uid"


def _baby() -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Parker', 'born', %s)
            """,
            (baby_id, _OWNER),
        )
    return baby_id


def _event(baby_id: uuid.UUID, title: str, catalog_id: str | None) -> uuid.UUID:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO events (
                baby_profile_id, created_by_firebase_uid, title, starts_at,
                catalog_suggestion_id
            )
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
            """,
            (baby_id, _OWNER, title, datetime(2026, 5, 1, 12, tzinfo=timezone.utc), catalog_id),
        ).fetchone()
    return row["id"]


def _item(baby_id: uuid.UUID, name: str, catalog_id: str | None = None) -> uuid.UUID:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO registry_items (
                baby_profile_id, created_by_firebase_uid, name, catalog_suggestion_id
            )
            VALUES (%s, %s, %s, %s)
            RETURNING id
            """,
            (baby_id, _OWNER, name, catalog_id),
        ).fetchone()
    return row["id"]


def _catalog_id(table: str, row_id: uuid.UUID) -> str | None:
    with get_connection() as conn:
        row = conn.execute(
            f"SELECT catalog_suggestion_id FROM {table} WHERE id = %s", (row_id,)
        ).fetchone()
    return row["catalog_suggestion_id"]


def _apply_migration() -> None:
    from lanonna_api.config import settings

    with psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
        dbname=settings.db_name,
    ) as conn:
        with psycopg.ClientCursor(conn) as cur:
            cur.execute(_MIGRATION.read_text())


def test_backfill_links_old_seeds_and_skips_conflicts():
    resolve_app_user(_OWNER, "owner@example.test")
    baby = _baby()
    checkup = _event(baby, "First Checkup", "first_checkup")
    swaddles = _item(baby, "Swaddles")
    crib = _item(baby, "Crib")
    second_crib = _item(baby, "Crib")
    diapers = _item(baby, "Diapers")
    renamed = _item(baby, "Swaddles for grandma")

    # This baby already has both catalog ids, so its old rows stay as they are.
    other = _baby()
    other_checkup = _event(other, "First Checkup", "first_checkup")
    _event(other, "First pediatric visit", "first_pediatric_visit")
    other_diapers = _item(other, "Diapers")
    _item(other, "Diapers (newborn)", "diaper_stockpile")

    _apply_migration()
    _apply_migration()  # idempotent

    assert _catalog_id("events", checkup) == "first_pediatric_visit"
    assert _catalog_id("registry_items", swaddles) == "swaddle_blankets"
    assert _catalog_id("registry_items", crib) == "crib_mattress"
    assert _catalog_id("registry_items", second_crib) is None
    assert _catalog_id("registry_items", diapers) == "diaper_stockpile"
    assert _catalog_id("registry_items", renamed) is None
    assert _catalog_id("events", other_checkup) == "first_checkup"
    assert _catalog_id("registry_items", other_diapers) is None
