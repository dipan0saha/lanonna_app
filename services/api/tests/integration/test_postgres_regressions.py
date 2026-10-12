"""SQL regressions that mocked repositories cannot see (#3, #31, #36, #37)."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.calendar import set_rsvp
from lanonna_api.domain.onboarding import onboarding_status_for_user
from lanonna_api.domain.search import search_baby_content
from lanonna_api.domain.user_errors import UserDeletedError
from lanonna_api.repositories.events import create_event
from lanonna_api.repositories.invitations import email_is_member
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _snap(firebase_uid: str) -> dict:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT email, updated_at, last_seen_at, deleted_at, xmin::text AS xmin
            FROM app_users
            WHERE firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchone()
    assert row is not None
    return dict(row)


def test_search_runs_against_real_columns_including_suggested_name():
    owner = "search-owner"
    resolve_app_user(owner, "owner@example.com")
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
        conn.execute(
            """
            INSERT INTO photos (
                baby_profile_id, uploader_firebase_uid, status, caption
            )
            VALUES (%s, %s, 'ready', 'QA gallery — shower day')
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO events (baby_profile_id, created_by_firebase_uid, title, starts_at)
            VALUES (%s, %s, 'Gender reveal', %s)
            """,
            (baby_id, owner, datetime(2026, 6, 1, tzinfo=timezone.utc)),
        )
        conn.execute(
            """
            INSERT INTO registry_items (baby_profile_id, created_by_firebase_uid, name)
            VALUES (%s, %s, 'QA Purchased Stroller')
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO name_suggestions (
                baby_profile_id, suggested_by_firebase_uid, suggested_name, gender
            )
            VALUES (%s, %s, 'James', 'male')
            """,
            (baby_id, owner),
        )

    qa = search_baby_content(owner, baby_id, "QA")
    assert [p["caption"] for p in qa["photos"]] == ["QA gallery — shower day"]
    assert [r["name"] for r in qa["registry_items"]] == ["QA Purchased Stroller"]
    assert qa["events"] == []
    assert qa["name_suggestions"] == []

    gender = search_baby_content(owner, baby_id, "Gender")
    assert [e["title"] for e in gender["events"]] == ["Gender reveal"]

    james = search_baby_content(owner, baby_id, "james")
    assert [n["name"] for n in james["name_suggestions"]] == ["James"]

    empty = search_baby_content(owner, baby_id, "no-such-thing")
    assert empty["photos"] == []
    assert empty["events"] == []
    assert empty["registry_items"] == []
    assert empty["name_suggestions"] == []

    # A literal percent must not match every row, and a quote must not 500.
    percent = search_baby_content(owner, baby_id, "%")
    assert percent["photos"] == []
    assert percent["events"] == []
    assert percent["registry_items"] == []
    assert percent["name_suggestions"] == []
    quoted = search_baby_content(owner, baby_id, "o'brien")
    assert quoted["photos"] == []


def test_resolve_app_user_does_not_null_email_or_write_when_unchanged():
    uid = "prov-user"
    first = resolve_app_user(uid, "follower@example.com")
    assert first["email"] == "follower@example.com"
    before = _snap(uid)

    for _ in range(10):
        resolve_app_user(uid, "follower@example.com")
    unchanged = _snap(uid)
    assert unchanged["xmin"] == before["xmin"]
    assert unchanged["email"] == "follower@example.com"
    assert unchanged["updated_at"] == before["updated_at"]

    resolve_app_user(uid, None)
    still = _snap(uid)
    assert still["email"] == "follower@example.com"
    assert still["xmin"] == before["xmin"]

    resolve_app_user(uid, "new@example.com")
    renamed = _snap(uid)
    assert renamed["email"] == "new@example.com"
    assert renamed["updated_at"] != before["updated_at"]
    assert renamed["xmin"] != before["xmin"]

    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET last_seen_at = now() - interval '16 minutes'
            WHERE firebase_uid = %s
            """,
            (uid,),
        )
    seen_before = _snap(uid)
    resolve_app_user(uid, "new@example.com")
    seen_after = _snap(uid)
    assert seen_after["email"] == "new@example.com"
    assert seen_after["updated_at"] == seen_before["updated_at"]
    assert seen_after["last_seen_at"] > seen_before["last_seen_at"]


def test_rsvp_does_not_clear_email_and_membership_check_still_matches():
    owner = "rsvp-owner"
    follower = "rsvp-follower"
    resolve_app_user(owner, "owner@example.com")
    resolve_app_user(follower, "follower@example.com")
    baby_id = uuid.uuid4()
    starts = datetime.now(timezone.utc) + timedelta(days=1)
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET display_name = 'Follower'
            WHERE firebase_uid = %s
            """,
            (follower,),
        )
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Baby', 'expecting', %s)
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created'), (%s, %s, 'follower', 'invite')
            """,
            (baby_id, owner, baby_id, follower),
        )
    event = create_event(
        baby_id,
        owner,
        title="Shower",
        starts_at=starts,
        ends_at=None,
        description=None,
        location=None,
        video_call_url=None,
        cover_photo_id=None,
    )
    before = _snap(follower)
    set_rsvp(follower, baby_id, event["id"], "going")
    after = _snap(follower)
    assert after["email"] == "follower@example.com"
    assert after["updated_at"] == before["updated_at"]
    assert email_is_member(baby_id, "follower@example.com") is True


def test_tombstoned_user_is_not_rewritten():
    uid = "deleted-user"
    resolve_app_user(uid, "gone@example.com")
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET email = NULL,
                deleted_at = now(),
                updated_at = updated_at
            WHERE firebase_uid = %s
            """,
            (uid,),
        )
    before = _snap(uid)
    assert before["email"] is None
    assert before["deleted_at"] is not None
    with pytest.raises(UserDeletedError):
        resolve_app_user(uid, "restored@example.com")
    after = _snap(uid)
    assert after["email"] is None
    assert after["updated_at"] == before["updated_at"]
    assert after["xmin"] == before["xmin"]


def _profile_user(uid: str, email: str) -> None:
    resolve_app_user(uid, email)
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET display_name = %s,
                terms_accepted_at = now()
            WHERE firebase_uid = %s
            """,
            (uid, uid),
        )


def test_onboarding_gate_uses_created_membership_not_any_owner_role():
    creator = "creator-uid"
    co_owner = "co-owner-uid"
    follower = "follower-uid"
    _profile_user(creator, "creator@example.com")
    _profile_user(co_owner, "coowner@example.com")
    _profile_user(follower, "follower@example.com")
    created_baby = uuid.uuid4()
    invited_baby = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES
                (%s, 'Created', 'expecting', %s),
                (%s, 'Invited', 'expecting', %s)
            """,
            (created_baby, creator, invited_baby, co_owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role, joined_via
            )
            VALUES
                (%s, %s, 'owner', 'created'),
                (%s, %s, 'owner', 'invite'),
                (%s, %s, 'follower', 'invite')
            """,
            (
                created_baby,
                creator,
                invited_baby,
                co_owner,
                invited_baby,
                follower,
            ),
        )

    creator_status = onboarding_status_for_user(creator, email_verified=True)
    assert creator_status["needs_owner_onboarding"] is True
    assert creator_status["can_access_main_app"] is False
    assert creator_status["owner_onboarding_baby_profile_id"] == created_baby

    # created_by was stamped on the co-owner (the 024 backfill mistake) but
    # the membership was an invite, so owner onboarding must not run.
    co_status = onboarding_status_for_user(co_owner, email_verified=True)
    assert co_status["has_owner_baby"] is True
    assert co_status["needs_owner_onboarding"] is False
    assert co_status["can_access_main_app"] is True
    assert co_status["owner_onboarding_baby_profile_id"] is None

    follower_status = onboarding_status_for_user(follower, email_verified=True)
    assert follower_status["needs_owner_onboarding"] is False
    assert follower_status["can_access_main_app"] is True
