"""Optional baby name (L-36) and migration 039 on real Postgres."""

from __future__ import annotations

import uuid
from datetime import date
from pathlib import Path
from unittest.mock import patch

import psycopg
import pytest
from psycopg.types.json import Json

from lanonna_api.db import get_connection
from lanonna_api.domain.home import announce_arrival
from lanonna_api.repositories.babies import (
    create_baby_with_owner_membership,
    get_baby_for_owner,
    update_baby_for_owner,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_MIGRATION_039 = (
    Path(__file__).resolve().parents[4]
    / "infra/db/migrations/039_baby_name_nullable_gender_not_null.sql"
)


def _user(tag: str) -> str:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    return uid


def test_unnamed_baby_is_stored_as_null_and_name_can_be_set_and_cleared():
    owner = _user("owner")
    row = create_baby_with_owner_membership(owner, None, "unknown", None, None, "expecting")
    assert row["name"] is None
    assert row["gender"] == "unknown"

    named = update_baby_for_owner(owner, row["id"], {"name": "Parker"})
    assert named["name"] == "Parker"
    cleared = update_baby_for_owner(owner, row["id"], {"name": None})
    assert cleared["name"] is None
    assert get_baby_for_owner(owner, row["id"])["name"] is None


def test_schema_rejects_blank_names_and_null_gender():
    owner = _user("owner")
    with pytest.raises(psycopg.errors.CheckViolation):
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO baby_profiles (name, lifecycle_status, created_by_firebase_uid)"
                " VALUES ('  ', 'expecting', %s)",
                (owner,),
            )
    with pytest.raises(psycopg.errors.NotNullViolation):
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO baby_profiles (gender, lifecycle_status, created_by_firebase_uid)"
                " VALUES (NULL, 'expecting', %s)",
                (owner,),
            )
    with get_connection() as conn:
        default_gender = conn.execute(
            "INSERT INTO baby_profiles (lifecycle_status, created_by_firebase_uid)"
            " VALUES ('expecting', %s) RETURNING gender",
            (owner,),
        ).fetchone()["gender"]
    assert default_gender == "unknown"


def test_arrival_of_an_unnamed_baby_records_no_baby_name_param():
    owner = _user("owner")
    row = create_baby_with_owner_membership(owner, None, "unknown", None, None, "expecting")
    with patch("lanonna_api.domain.home.safe_enqueue_fan_out"):
        announce_arrival(owner, row["id"], date.today())
    with get_connection() as conn:
        params = conn.execute(
            "SELECT params FROM activity_events WHERE baby_profile_id = %s"
            " AND event_type = 'baby_arrived'",
            (row["id"],),
        ).fetchone()["params"]
    assert params == {}


def test_migration_039_clears_only_the_persisted_default_name():
    owner = _user("owner")
    with get_connection() as conn:
        # Recreate the pre-039 schema for the legacy rows below.
        conn.execute("ALTER TABLE baby_profiles DROP CONSTRAINT baby_profiles_name_not_blank")
        conn.execute("ALTER TABLE baby_profiles ALTER COLUMN gender DROP NOT NULL")

        def baby(name: str, gender: str | None = "male") -> uuid.UUID:
            return conn.execute(
                "INSERT INTO baby_profiles (name, gender, lifecycle_status, created_by_firebase_uid)"
                " VALUES (%s, %s, 'expecting', %s) RETURNING id",
                (name, gender, owner),
            ).fetchone()["id"]

        default = baby("Baby", None)
        blank = baby("   ")
        lowercase = baby("baby")
        prefixed = baby("Baby Parker")
        real = baby("Parker", "female")

        def activity(baby_id: uuid.UUID, params: dict) -> uuid.UUID:
            return conn.execute(
                "INSERT INTO activity_events (baby_profile_id, actor_firebase_uid, event_type,"
                " summary, params) VALUES (%s, %s, 'baby_arrived', 'x', %s) RETURNING id",
                (baby_id, owner, Json(params)),
            ).fetchone()["id"]

        default_activity = activity(default, {"baby_name": "Baby"})
        prefixed_activity = activity(prefixed, {"baby_name": "Baby Parker"})
        note = conn.execute(
            "INSERT INTO notifications (firebase_uid, baby_profile_id, title, body,"
            " notification_kind, params) VALUES (%s, %s, 't', 'b', 'baby_arrived', %s)"
            " RETURNING id",
            (owner, default, Json({"baby_name": "Baby"})),
        ).fetchone()["id"]
        conn.commit()

    for _ in range(2):  # forward-only and idempotent
        with get_connection() as conn:
            with psycopg.ClientCursor(conn) as cur:
                cur.execute(_MIGRATION_039.read_text())
            conn.commit()

    with get_connection() as conn:
        rows = {
            r["id"]: (r["name"], r["gender"])
            for r in conn.execute(
                "SELECT id, name, gender FROM baby_profiles WHERE id = ANY(%s)",
                ([default, blank, lowercase, prefixed, real],),
            )
        }
        acts = {
            r["id"]: r["params"]
            for r in conn.execute(
                "SELECT id, params FROM activity_events WHERE id = ANY(%s)",
                ([default_activity, prefixed_activity],),
            )
        }
        note_params = conn.execute(
            "SELECT params FROM notifications WHERE id = %s", (note,)
        ).fetchone()["params"]

    assert rows[default] == (None, "unknown")
    assert rows[blank] == (None, "male")
    assert rows[lowercase] == ("baby", "male")
    assert rows[prefixed] == ("Baby Parker", "male")
    assert rows[real] == ("Parker", "female")
    assert acts[default_activity] == {}
    assert acts[prefixed_activity] == {"baby_name": "Baby Parker"}
    assert note_params == {}
