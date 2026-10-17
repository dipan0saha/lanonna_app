"""Structured activity / inbox rows (migration 038) on real Postgres."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path

import psycopg
import pytest
from psycopg.types.json import Json

from lanonna_api.db import get_connection
from lanonna_api.domain.activity_feed import serialize_activity_item
from lanonna_api.repositories.activity_events import insert_activity_event, list_recent_for_baby
from lanonna_api.repositories.memberships import list_baby_members
from lanonna_api.repositories.notifications import list_notifications_for_user
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_MIGRATION_038 = (
    Path(__file__).resolve().parents[4]
    / "infra/db/migrations/038_structured_notification_activity_params.sql"
)


def _user(tag: str, display_name: str | None = None) -> str:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    if display_name is not None:
        with get_connection() as conn:
            conn.execute(
                "UPDATE app_users SET display_name = %s WHERE firebase_uid = %s",
                (display_name, uid),
            )
    return uid


def _baby(owner: str, *followers: str, name: str | None = "Parker") -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, %s, 'expecting', %s)",
            (baby_id, name, owner),
        )
        for uid, role in [(owner, "owner"), *((f, "follower") for f in followers)]:
            conn.execute(
                "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
                " VALUES (%s, %s, %s, 'created')",
                (baby_id, uid, role),
            )
    return baby_id


def _items(baby_id: uuid.UUID) -> list[dict]:
    return [serialize_activity_item(r) for r in list_recent_for_baby(baby_id, limit=20)]


def test_activity_rows_round_trip_params_and_null_names():
    owner = _user("owner", "Sarah")
    nameless = _user("nameless", "   ")
    baby_id = _baby(owner, nameless)

    insert_activity_event(baby_id, nameless, "name_suggested", {"suggested_name": "Ivy"})
    insert_activity_event(
        baby_id, owner, "member_removed", payload={"target_firebase_uid": nameless}
    )
    insert_activity_event(baby_id, nameless, "registry_claimed", {"item_name": "Swaddles"})

    claimed, removed, suggested = _items(baby_id)
    assert suggested["params"] == {"suggested_name": "Ivy"}
    assert suggested["actor_display_name"] is None
    assert suggested["summary"] == 'Someone suggested the name "Ivy"'
    assert removed["actor_display_name"] == "Sarah"
    assert removed["target_display_name"] is None
    assert claimed["event_type"] == "registry_claimed"
    assert claimed["actor_display_name"] is None
    assert claimed["params"] == {"item_name": "Swaddles"}


def test_member_list_carries_no_email_or_relationship_label():
    owner = _user("owner", "Sarah")
    follower = _user("follower")
    baby_id = _baby(owner, follower)
    rows = list_baby_members(baby_id)
    assert {tuple(sorted(r)) for r in rows} == {
        ("created_at", "display_name", "firebase_uid", "role")
    }
    assert {r["firebase_uid"]: r["display_name"] for r in rows} == {
        owner: "Sarah",
        follower: None,
    }


def _rerun_038() -> None:
    with get_connection() as conn:
        with psycopg.ClientCursor(conn) as cur:
            cur.execute(_MIGRATION_038.read_text())
        conn.commit()


def _legacy_notification(recipient, baby_id, title, deep_link=None) -> uuid.UUID:
    nid = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO notifications (id, firebase_uid, baby_profile_id, title, body, deep_link)"
            " VALUES (%s, %s, %s, %s, 'legacy body', %s)",
            (nid, recipient, baby_id, title, deep_link),
        )
    return nid


def _legacy_activity(baby_id, actor, event_type, summary, payload=None) -> uuid.UUID:
    aid = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO activity_events (id, baby_profile_id, actor_firebase_uid, event_type,"
            " summary, payload) VALUES (%s, %s, %s, %s, %s, %s)",
            (aid, baby_id, actor, event_type, summary, Json(payload) if payload else None),
        )
    return aid


def test_migration_038_backfills_legacy_rows_from_structured_sources():
    owner = _user("owner", "Sarah")
    follower = _user("follower", "Ann")
    baby_id = _baby(owner, follower)
    unnamed_baby = _baby(owner, name=None)
    event_id, item_id, suggestion_id, photo_id = (uuid.uuid4() for _ in range(4))
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO events (id, baby_profile_id, created_by_firebase_uid, title, starts_at)"
            " VALUES (%s, %s, %s, 'Shower', %s)",
            (event_id, baby_id, owner, datetime(2026, 6, 1, tzinfo=timezone.utc)),
        )
        conn.execute(
            "INSERT INTO registry_items (id, baby_profile_id, created_by_firebase_uid, name)"
            " VALUES (%s, %s, %s, 'Stroller')",
            (item_id, baby_id, owner),
        )
        conn.execute(
            "INSERT INTO name_suggestions (id, baby_profile_id, suggested_by_firebase_uid,"
            " suggested_name, gender) VALUES (%s, %s, %s, 'James', 'male')",
            (suggestion_id, baby_id, follower),
        )
        conn.execute(
            "INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status, caption)"
            " VALUES (%s, %s, %s, 'ready', ' Nursery ')",
            (photo_id, baby_id, owner),
        )

    n_squish = _legacy_notification(owner, baby_id, "New squish", f"/gallery/photo/{photo_id}")
    n_photo_comment = _legacy_notification(
        owner, baby_id, "New comment", f"/gallery/photo/{photo_id}"
    )
    n_event_comment = _legacy_notification(
        owner, baby_id, "New comment", f"/calendar/event/{event_id}"
    )
    n_event = _legacy_notification(follower, baby_id, "New event", f"/calendar/event/{event_id}")
    n_arrived = _legacy_notification(follower, unnamed_baby, "Baby has arrived!")
    n_rsvp = _legacy_notification(owner, baby_id, "New RSVP", f"/calendar/event/{event_id}")

    a_claim = _legacy_activity(
        baby_id, follower, "registry_purchased", 'Someone is buying "Stroller"',
        {"registry_item_id": str(item_id)},
    )
    a_purchase = _legacy_activity(
        baby_id, owner, "registry_purchased", 'Sarah marked "Stroller" as purchased',
        {"registry_item_id": str(item_id)},
    )
    a_photo = _legacy_activity(
        baby_id, owner, "photo_shared", 'Sarah shared "Nursery"', {"photo_id": str(photo_id)}
    )
    a_name = _legacy_activity(
        baby_id, follower, "name_suggested", 'Suggested the name "James"',
        {"name_suggestion_id": str(suggestion_id)},
    )
    a_gender = _legacy_activity(baby_id, follower, "gender_vote_cast", 'Guessed "female"')
    a_gone = _legacy_activity(
        baby_id, owner, "event_created", "Sarah added an event",
        {"event_id": str(uuid.uuid4())},
    )

    _rerun_038()
    _rerun_038()  # forward-only and idempotent

    with get_connection() as conn:
        notes = {
            r["id"]: (r["notification_kind"], r["params"])
            for r in conn.execute("SELECT id, notification_kind, params FROM notifications")
        }
        acts = {
            r["id"]: (r["event_type"], r["params"])
            for r in conn.execute("SELECT id, event_type, params FROM activity_events")
        }
    assert notes[n_squish] == ("photo_squished", {})
    assert notes[n_photo_comment] == ("photo_commented", {})
    assert notes[n_event_comment] == ("event_commented", {"event_title": "Shower"})
    assert notes[n_event] == ("event_created", {"event_title": "Shower"})
    assert notes[n_arrived] == ("baby_arrived", {})
    assert notes[n_rsvp] == (None, {})
    assert acts[a_claim] == ("registry_claimed", {"item_name": "Stroller"})
    assert acts[a_purchase] == ("registry_purchased", {"item_name": "Stroller"})
    assert acts[a_photo] == ("photo_shared", {"caption": "Nursery"})
    assert acts[a_name] == ("name_suggested", {"suggested_name": "James"})
    assert acts[a_gender] == ("gender_vote_cast", {"gender": "female"})
    assert acts[a_gone] == ("event_created", {})

    inbox = {r["id"]: r for r in list_notifications_for_user(owner, limit=10)}
    assert inbox[n_event_comment]["params"] == {"event_title": "Shower"}
    assert inbox[n_rsvp]["notification_kind"] is None


def test_notification_kind_check_rejects_unknown_kinds():
    owner = _user("owner")
    with pytest.raises(psycopg.errors.CheckViolation):
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO notifications (firebase_uid, title, body, notification_kind)"
                " VALUES (%s, 't', 'b', 'weekly_digest')",
                (owner,),
            )
