"""A removed member is not a participant, even while their account stays active."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from pathlib import Path

import psycopg
import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.announcements import get_announcement
from lanonna_api.repositories.events import (
    list_event_comments,
    list_rsvps_for_event,
    rsvp_summary,
)
from lanonna_api.repositories.home_counts import home_summary_counts
from lanonna_api.repositories.fun import (
    birthdate_vote_histogram,
    gender_vote_totals,
    list_gender_voters,
    list_name_suggestions,
)
from lanonna_api.repositories.memberships import (
    reactivate_membership,
    soft_remove_membership,
    soft_remove_memberships_on_babies,
)
from lanonna_api.repositories.photos import (
    get_photo_detail_row,
    list_photo_comments,
    list_photos_for_baby,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_MIGRATION = (
    Path(__file__).resolve().parents[4]
    / "infra/db/migrations/033_drop_ended_membership_participation.sql"
)


def _user(uid: str, email: str, name: str) -> None:
    resolve_app_user(uid, email)
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET display_name = %s
            WHERE firebase_uid = %s
            """,
            (name, uid),
        )


def _baby(owner: str, name: str = "Parker") -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, %s, 'expecting', %s)
            """,
            (baby_id, name, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, owner),
        )
    return baby_id


def _follower(baby_id: uuid.UUID, uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'follower', 'invite')
            """,
            (baby_id, uid),
        )


def _end_membership_keep_rows(baby_id: uuid.UUID, uid: str) -> None:
    """Mark the membership ended without the presence purge."""
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE baby_memberships
            SET removed_at = now()
            WHERE baby_profile_id = %s AND firebase_uid = %s
            """,
            (baby_id, uid),
        )


def _count(table: str, uid: str, baby_id: uuid.UUID | None = None) -> int:
    if table == "event_rsvps":
        sql = """
            SELECT COUNT(*)::int AS n
            FROM event_rsvps r
            JOIN events e ON e.id = r.event_id
            WHERE r.firebase_uid = %s
              AND (%s::uuid IS NULL OR e.baby_profile_id = %s)
        """
        params = (uid, baby_id, baby_id)
    elif table == "votes":
        sql = """
            SELECT COUNT(*)::int AS n FROM votes
            WHERE firebase_uid = %s
              AND (%s::uuid IS NULL OR baby_profile_id = %s)
        """
        params = (uid, baby_id, baby_id)
    elif table == "name_suggestion_likes":
        sql = """
            SELECT COUNT(*)::int AS n
            FROM name_suggestion_likes l
            JOIN name_suggestions n ON n.id = l.name_suggestion_id
            WHERE l.firebase_uid = %s
              AND (%s::uuid IS NULL OR n.baby_profile_id = %s)
        """
        params = (uid, baby_id, baby_id)
    elif table == "photo_squishes":
        sql = """
            SELECT COUNT(*)::int AS n
            FROM photo_squishes s
            JOIN photos p ON p.id = s.photo_id
            WHERE s.firebase_uid = %s
              AND (%s::uuid IS NULL OR p.baby_profile_id = %s)
        """
        params = (uid, baby_id, baby_id)
    elif table == "announcement_squishes":
        sql = """
            SELECT COUNT(*)::int AS n
            FROM announcement_squishes s
            JOIN birth_announcements a ON a.id = s.announcement_id
            WHERE s.firebase_uid = %s
              AND (%s::uuid IS NULL OR a.baby_profile_id = %s)
        """
        params = (uid, baby_id, baby_id)
    else:
        raise AssertionError(table)
    with get_connection() as conn:
        row = conn.execute(sql, params).fetchone()
    return int(row["n"])


def _seed_presence(baby_id: uuid.UUID, owner: str, active: str, former: str) -> dict:
    starts = datetime(2026, 8, 1, tzinfo=timezone.utc)
    event_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    only_former_photo_id = uuid.uuid4()
    suggestion_id = uuid.uuid4()
    former_suggestion_id = uuid.uuid4()
    announcement_id = uuid.uuid4()
    registry_item_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO events (
                id, baby_profile_id, created_by_firebase_uid, title, starts_at
            )
            VALUES (%s, %s, %s, 'Shower', %s)
            """,
            (event_id, baby_id, owner, starts),
        )
        conn.execute(
            """
            INSERT INTO event_rsvps (event_id, firebase_uid, status)
            VALUES (%s, %s, 'going'), (%s, %s, 'maybe')
            """,
            (event_id, active, event_id, former),
        )
        conn.execute(
            """
            INSERT INTO event_comments (event_id, author_firebase_uid, body)
            VALUES (%s, %s, 'See you there')
            """,
            (event_id, former),
        )
        conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type, gender_value, is_anonymous
            )
            VALUES
                (%s, %s, 'gender', 'female', false),
                (%s, %s, 'gender', 'male', false)
            """,
            (baby_id, active, baby_id, former),
        )
        conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type, predicted_birth_date
            )
            VALUES (%s, %s, 'birthdate', %s), (%s, %s, 'birthdate', %s)
            """,
            (
                baby_id,
                active,
                date(2026, 9, 1),
                baby_id,
                former,
                date(2026, 9, 2),
            ),
        )
        conn.execute(
            """
            INSERT INTO name_suggestions (
                id, baby_profile_id, suggested_by_firebase_uid, suggested_name, gender
            )
            VALUES (%s, %s, %s, 'James', 'male'),
                   (%s, %s, %s, 'Robin', 'unknown')
            """,
            (suggestion_id, baby_id, owner, former_suggestion_id, baby_id, former),
        )
        conn.execute(
            """
            INSERT INTO name_suggestion_likes (name_suggestion_id, firebase_uid)
            VALUES (%s, %s), (%s, %s)
            """,
            (suggestion_id, active, suggestion_id, former),
        )
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status, caption
            )
            VALUES (%s, %s, %s, 'ready', 'Shower day'),
                   (%s, %s, %s, 'ready', 'Only a former squish')
            """,
            (photo_id, baby_id, former, only_former_photo_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid)
            VALUES (%s, %s), (%s, %s), (%s, %s)
            """,
            (photo_id, active, photo_id, former, only_former_photo_id, former),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (photo_id, author_firebase_uid, body)
            VALUES (%s, %s, 'Love this')
            """,
            (photo_id, former),
        )
        conn.execute(
            """
            INSERT INTO birth_announcements (
                id, baby_profile_id, created_by_firebase_uid, first_name
            )
            VALUES (%s, %s, %s, 'Parker')
            """,
            (announcement_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO announcement_squishes (announcement_id, firebase_uid)
            VALUES (%s, %s), (%s, %s)
            """,
            (announcement_id, active, announcement_id, former),
        )
        conn.execute(
            """
            INSERT INTO registry_items (
                id, baby_profile_id, created_by_firebase_uid, name
            )
            VALUES (%s, %s, %s, 'Blanket')
            """,
            (registry_item_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO registry_purchases (registry_item_id, purchased_by_firebase_uid)
            VALUES (%s, %s)
            """,
            (registry_item_id, former),
        )
    return {
        "event_id": event_id,
        "photo_id": photo_id,
        "only_former_photo_id": only_former_photo_id,
        "suggestion_id": suggestion_id,
        "announcement_id": announcement_id,
        "registry_item_id": registry_item_id,
    }


def _assert_former_excluded(ids: dict, active: str) -> None:
    summary = rsvp_summary(ids["event_id"])
    assert summary == {"going": 1, "maybe": 0, "cant_go": 0}
    attendees = list_rsvps_for_event(ids["event_id"])
    assert [row["firebase_uid"] for row in attendees] == [active]
    assert attendees[0]["display_name"] == "Aunt May"

    counts = home_summary_counts(ids["baby_id"])
    assert (counts["vote_count"], counts["male_votes"], counts["female_votes"]) == (1, 0, 1)
    assert counts["top_birthdate_guess"] == date(2026, 9, 1)
    assert gender_vote_totals(ids["baby_id"]) == {"male": 0, "female": 1}
    voters = list_gender_voters(ids["baby_id"])
    assert [row["firebase_uid"] for row in voters] == [active]
    histogram = birthdate_vote_histogram(ids["baby_id"])
    assert [row["predicted_birth_date"] for row in histogram] == [date(2026, 9, 1)]

    names = {row["suggested_name"]: row for row in list_name_suggestions(ids["baby_id"])}
    assert names["James"]["like_count"] == 1
    assert names["Robin"]["author_display_name"] == "Uncle Dan"

    assert (
        get_photo_detail_row(ids["baby_id"], ids["photo_id"], "nobody")["squish_count"]
        == 1
    )
    assert (
        get_photo_detail_row(ids["baby_id"], ids["only_former_photo_id"], "nobody")["squish_count"]
        == 0
    )
    photos = {
        row["id"]: row
        for row in list_photos_for_baby(ids["baby_id"], ready_only=True)
    }
    assert photos[ids["photo_id"]]["squish_count"] == 1
    assert photos[ids["photo_id"]]["comment_count"] == 1
    assert photos[ids["photo_id"]]["uploader_display_name"] == "Uncle Dan"
    favorites = list_photos_for_baby(ids["baby_id"], ready_only=True, sort="favorites")
    assert [row["id"] for row in favorites] == [ids["photo_id"]]

    announcement = get_announcement(ids["baby_id"])
    assert announcement is not None
    assert announcement["squish_count"] == 1

    comments = list_event_comments(ids["event_id"])
    assert [row["body"] for row in comments] == ["See you there"]
    assert comments[0]["author_display_name"] == "Uncle Dan"
    photo_comments = list_photo_comments(ids["photo_id"])
    assert [row["body"] for row in photo_comments] == ["Love this"]


def test_reads_skip_removed_member_and_keep_authored_content():
    owner = "rm-owner"
    active = "rm-active"
    former = "rm-former"
    _user(owner, "rm-owner@example.com", "Owner")
    _user(active, "rm-active@example.com", "Aunt May")
    _user(former, "rm-former@example.com", "Uncle Dan")
    baby_id = _baby(owner)
    _follower(baby_id, active)
    _follower(baby_id, former)
    ids = _seed_presence(baby_id, owner, active, former)
    ids["baby_id"] = baby_id
    _end_membership_keep_rows(baby_id, former)

    _assert_former_excluded(ids, active)
    with get_connection() as conn:
        claim = conn.execute(
            """
            SELECT purchased_by_firebase_uid
            FROM registry_purchases
            WHERE registry_item_id = %s
            """,
            (ids["registry_item_id"],),
        ).fetchone()
    assert claim["purchased_by_firebase_uid"] == former
    for table in (
        "event_rsvps",
        "votes",
        "name_suggestion_likes",
        "photo_squishes",
        "announcement_squishes",
    ):
        assert _count(table, former, baby_id) > 0


def test_migration_drops_presence_left_by_ended_memberships():
    owner = "mig-owner"
    active = "mig-active"
    former = "mig-former"
    _user(owner, "mig-owner@example.com", "Owner")
    _user(active, "mig-active@example.com", "Aunt May")
    _user(former, "mig-former@example.com", "Uncle Dan")
    baby_id = _baby(owner)
    _follower(baby_id, active)
    _follower(baby_id, former)
    ids = _seed_presence(baby_id, owner, active, former)
    ids["baby_id"] = baby_id
    _end_membership_keep_rows(baby_id, former)

    with get_connection() as conn:
        with psycopg.ClientCursor(conn) as cur:
            cur.execute(_MIGRATION.read_text())

    for table in (
        "event_rsvps",
        "votes",
        "name_suggestion_likes",
        "photo_squishes",
        "announcement_squishes",
    ):
        assert _count(table, former, baby_id) == 0
        assert _count(table, active, baby_id) > 0
    _assert_former_excluded(ids, active)
    with get_connection() as conn:
        claim = conn.execute(
            "SELECT 1 FROM registry_purchases WHERE registry_item_id = %s",
            (ids["registry_item_id"],),
        ).fetchone()
    assert claim is not None
    names = list_name_suggestions(baby_id)
    assert "Robin" in {row["suggested_name"] for row in names}


def test_remove_purges_presence_on_that_baby_only_and_reactivate_does_not_restore():
    owner = "scope-owner"
    member = "scope-member"
    _user(owner, "scope-owner@example.com", "Owner")
    _user(member, "scope-member@example.com", "Aunt May")
    home = _baby(owner, "Home")
    other = _baby(owner, "Other")
    _follower(home, member)
    _follower(other, member)
    home_ids = _seed_presence(home, owner, owner, member)
    other_ids = _seed_presence(other, owner, owner, member)

    assert soft_remove_membership(home, member) is True

    for table in (
        "event_rsvps",
        "votes",
        "name_suggestion_likes",
        "photo_squishes",
        "announcement_squishes",
    ):
        assert _count(table, member, home) == 0
        assert _count(table, member, other) > 0
    assert rsvp_summary(home_ids["event_id"])["maybe"] == 0
    assert rsvp_summary(other_ids["event_id"])["maybe"] == 1
    assert list_event_comments(home_ids["event_id"])[0]["body"] == "See you there"
    assert {row["suggested_name"] for row in list_name_suggestions(home)} == {
        "James",
        "Robin",
    }
    with get_connection() as conn:
        claim = conn.execute(
            "SELECT 1 FROM registry_purchases WHERE registry_item_id = %s",
            (home_ids["registry_item_id"],),
        ).fetchone()
    assert claim is not None

    assert reactivate_membership(home, member, "follower", "Aunt") is True
    assert rsvp_summary(home_ids["event_id"]) == {"going": 1, "maybe": 0, "cant_go": 0}
    assert _count("event_rsvps", member, home) == 0
    assert list_rsvps_for_event(home_ids["event_id"])[0]["firebase_uid"] == owner


def test_ending_every_membership_on_a_baby_purges_that_babys_presence():
    owner = "bulk-owner"
    member = "bulk-member"
    _user(owner, "bulk-owner@example.com", "Owner")
    _user(member, "bulk-member@example.com", "Aunt May")
    closing = _baby(owner, "Closing")
    staying = _baby(owner, "Staying")
    _follower(closing, member)
    _follower(staying, member)
    closing_ids = _seed_presence(closing, owner, member, owner)
    staying_ids = _seed_presence(staying, owner, member, owner)

    soft_remove_memberships_on_babies([closing])

    assert rsvp_summary(closing_ids["event_id"]) == {"going": 0, "maybe": 0, "cant_go": 0}
    assert _count("votes", member, closing) == 0
    assert _count("votes", owner, closing) == 0
    assert rsvp_summary(staying_ids["event_id"])["going"] == 1
    assert _count("event_rsvps", member, staying) == 1
    assert list_event_comments(closing_ids["event_id"])[0]["body"] == "See you there"
