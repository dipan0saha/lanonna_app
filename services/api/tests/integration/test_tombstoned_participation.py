"""Tombstoned accounts are not participants (FR-SET-005)."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.account_delete import soft_delete_account_rows
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
from lanonna_api.repositories.photos import (
    get_photo_detail_row,
    list_photo_comments,
    list_photos_for_baby,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


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


def _tombstone_keep_rows(uid: str) -> None:
    """Mark the account deleted without running the participation purge."""
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET display_name = 'Deleted user',
                email = NULL,
                deleted_at = now()
            WHERE firebase_uid = %s
            """,
            (uid,),
        )


def _member(baby_id: uuid.UUID, uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'follower', 'invite')
            """,
            (baby_id, uid),
        )


def _baby(owner: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Parker', 'expecting', %s)
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
    return baby_id


def _count(table: str, uid: str) -> int:
    with get_connection() as conn:
        row = conn.execute(
            f"SELECT COUNT(*)::int AS n FROM {table} WHERE firebase_uid = %s",
            (uid,),
        ).fetchone()
    return int(row["n"])


def test_reads_skip_tombstoned_participation_and_keep_authored_comments():
    owner = "part-owner"
    active = "part-active"
    gone = "part-gone"
    _user(owner, "owner@example.com", "Owner")
    _user(active, "active@example.com", "Aunt May")
    _user(gone, "gone@example.com", "Uncle Dan")
    baby_id = _baby(owner)
    _member(baby_id, active)
    _member(baby_id, gone)
    starts = datetime(2026, 8, 1, tzinfo=timezone.utc)
    event_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    only_gone_photo_id = uuid.uuid4()
    suggestion_id = uuid.uuid4()
    announcement_id = uuid.uuid4()
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
            (event_id, active, event_id, gone),
        )
        conn.execute(
            """
            INSERT INTO event_comments (event_id, author_firebase_uid, body)
            VALUES (%s, %s, 'See you there')
            """,
            (event_id, gone),
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
            (baby_id, active, baby_id, gone),
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
                gone,
                date(2026, 9, 2),
            ),
        )
        conn.execute(
            """
            INSERT INTO name_suggestions (
                id, baby_profile_id, suggested_by_firebase_uid, suggested_name, gender
            )
            VALUES (%s, %s, %s, 'James', 'male')
            """,
            (suggestion_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO name_suggestion_likes (name_suggestion_id, firebase_uid)
            VALUES (%s, %s), (%s, %s)
            """,
            (suggestion_id, active, suggestion_id, gone),
        )
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status, caption
            )
            VALUES (%s, %s, %s, 'ready', 'Shower day')
            """,
            (photo_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status, caption
            )
            VALUES (%s, %s, %s, 'ready', 'Only a deleted squish')
            """,
            (only_gone_photo_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid)
            VALUES (%s, %s), (%s, %s), (%s, %s)
            """,
            (photo_id, active, photo_id, gone, only_gone_photo_id, gone),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (photo_id, author_firebase_uid, body)
            VALUES (%s, %s, 'Love this')
            """,
            (photo_id, gone),
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
            (announcement_id, active, announcement_id, gone),
        )

    _tombstone_keep_rows(gone)

    summary = rsvp_summary(event_id)
    assert summary == {"going": 1, "maybe": 0, "cant_go": 0}
    attendees = list_rsvps_for_event(event_id)
    assert [row["firebase_uid"] for row in attendees] == [active]
    assert attendees[0]["display_name"] == "Aunt May"

    counts = home_summary_counts(baby_id)
    assert (counts["vote_count"], counts["male_votes"], counts["female_votes"]) == (1, 0, 1)
    assert counts["top_birthdate_guess"] == date(2026, 9, 1)
    assert gender_vote_totals(baby_id) == {"male": 0, "female": 1}
    voters = list_gender_voters(baby_id)
    assert [row["firebase_uid"] for row in voters] == [active]
    histogram = birthdate_vote_histogram(baby_id)
    assert [row["predicted_birth_date"] for row in histogram] == [date(2026, 9, 1)]
    assert histogram[0]["count"] == 1

    names = list_name_suggestions(baby_id)
    assert names[0]["like_count"] == 1
    assert names[0]["author_display_name"] == "Owner"

    assert (
        get_photo_detail_row(baby_id, photo_id, "nobody")["squish_count"]
        == 1
    )
    assert (
        get_photo_detail_row(baby_id, only_gone_photo_id, "nobody")["squish_count"]
        == 0
    )
    photos = {row["id"]: row for row in list_photos_for_baby(baby_id, ready_only=True)}
    assert photos[photo_id]["squish_count"] == 1
    assert photos[photo_id]["comment_count"] == 1
    assert photos[only_gone_photo_id]["squish_count"] == 0
    favorites = list_photos_for_baby(baby_id, ready_only=True, sort="favorites")
    assert [row["id"] for row in favorites] == [photo_id]

    announcement = get_announcement(baby_id)
    assert announcement is not None
    assert announcement["squish_count"] == 1
    assert announcement["comment_count"] == 0

    comments = list_event_comments(event_id)
    assert [row["body"] for row in comments] == ["See you there"]
    assert comments[0]["author_display_name"] == "Deleted user"
    photo_comments = list_photo_comments(photo_id)
    assert [row["body"] for row in photo_comments] == ["Love this"]
    assert photo_comments[0]["author_display_name"] == "Deleted user"


def test_delete_account_purges_participation_rows():
    owner = "purge-owner"
    _user(owner, "purge@example.com", "Owner")
    baby_id = _baby(owner)
    event_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    suggestion_id = uuid.uuid4()
    announcement_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO events (
                id, baby_profile_id, created_by_firebase_uid, title, starts_at
            )
            VALUES (%s, %s, %s, 'Shower', %s)
            """,
            (event_id, baby_id, owner, datetime(2026, 8, 1, tzinfo=timezone.utc)),
        )
        conn.execute(
            """
            INSERT INTO event_rsvps (event_id, firebase_uid, status)
            VALUES (%s, %s, 'going')
            """,
            (event_id, owner),
        )
        conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type, gender_value
            )
            VALUES (%s, %s, 'gender', 'female')
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO name_suggestions (
                id, baby_profile_id, suggested_by_firebase_uid, suggested_name, gender
            )
            VALUES (%s, %s, %s, 'James', 'male')
            """,
            (suggestion_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO name_suggestion_likes (name_suggestion_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (suggestion_id, owner),
        )
        conn.execute(
            """
            INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status)
            VALUES (%s, %s, %s, 'ready')
            """,
            (photo_id, baby_id, owner),
        )
        conn.execute(
            "INSERT INTO photo_squishes (photo_id, firebase_uid) VALUES (%s, %s)",
            (photo_id, owner),
        )
        conn.execute(
            """
            INSERT INTO birth_announcements (
                id, baby_profile_id, created_by_firebase_uid
            )
            VALUES (%s, %s, %s)
            """,
            (announcement_id, baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO announcement_squishes (announcement_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (announcement_id, owner),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (photo_id, author_firebase_uid, body)
            VALUES (%s, %s, 'Keep me')
            """,
            (photo_id, owner),
        )

    soft_delete_account_rows(owner, [])

    for table in (
        "event_rsvps",
        "votes",
        "name_suggestion_likes",
        "photo_squishes",
        "announcement_squishes",
    ):
        assert _count(table, owner) == 0
    assert rsvp_summary(event_id) == {"going": 0, "maybe": 0, "cant_go": 0}
    assert list_photo_comments(photo_id)[0]["body"] == "Keep me"
    assert list_name_suggestions(baby_id)[0]["suggested_name"] == "James"
