"""Account delete removes personal SQL rows the tombstone bypasses (issue #364)."""

from __future__ import annotations

import uuid
from pathlib import Path

import psycopg
import pytest
from lanonna_activity_copy import ActivityEventType, activity_summary
from psycopg.types.json import Json

from lanonna_api.db import get_connection
from lanonna_api.repositories.account_delete import delete_account_rows
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_MIGRATION_046 = (
    Path(__file__).resolve().parents[4]
    / "infra/db/migrations/046_tombstoned_personal_user_data.sql"
)


def _uid(label: str) -> str:
    return f"{label}-{uuid.uuid4().hex[:8]}"


def _user(uid: str, name: str) -> str:
    email = f"{uid}@example.com"
    resolve_app_user(uid, email)
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET display_name = %s, phone = '+15550100', birth_date = '1990-01-02',
                country_code = 'US', postal_code = '10001', last_seen_at = now(),
                biometric_unlock_enabled = true
            WHERE firebase_uid = %s
            """,
            (name, uid),
        )
    return email


def _count(sql: str, *params: object) -> int:
    with get_connection() as conn:
        return int(conn.execute(sql, params).fetchone()["n"])


def _shared_baby(owner: str, member: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Nora', 'expecting', %s)
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created'), (%s, %s, 'follower', 'invite')
            """,
            (baby_id, owner, baby_id, member),
        )
    return baby_id


def _seed_personal_rows(baby_id: uuid.UUID, owner: str, member: str, email: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO notifications (
                firebase_uid, baby_profile_id, title, body, notification_type,
                notification_kind, actor_firebase_uid, actor_display_name
            )
            VALUES (%s, %s, 'New comment', 'Mia commented on your photo', 'comment',
                    'photo_commented', %s, 'Mia'),
                   (%s, %s, 'New photo', 'Owner shared a new photo', 'photo',
                    'photo_shared', %s, 'Owner'),
                   (%s, NULL, 'Digest', 'Your weekly update', 'digest',
                    NULL, NULL, NULL)
            """,
            (owner, baby_id, member, member, baby_id, owner, owner),
        )
        conn.execute(
            """
            INSERT INTO device_tokens (firebase_uid, fcm_token, platform)
            VALUES (%s, %s, 'android')
            """,
            (member, f"token-{member}"),
        )
        ann_id = conn.execute(
            """
            INSERT INTO system_announcements (title, body, priority)
            VALUES ('Hello', 'World', 0) RETURNING id
            """
        ).fetchone()["id"]
        conn.execute(
            "INSERT INTO announcement_dismissals (announcement_id, firebase_uid) VALUES (%s, %s)",
            (ann_id, member),
        )
        conn.execute(
            """
            INSERT INTO biometric_credentials (firebase_uid, device_id, public_key_pem, algorithm)
            VALUES (%s, 'dev-1', 'pem', 'ecdsa_p256_sha256')
            """,
            (member,),
        )
        for status in ("accepted", "pending"):
            conn.execute(
                """
                INSERT INTO invitations (baby_profile_id, inviter_firebase_uid, invitee_email,
                                         role, token_hash, status, expires_at)
                VALUES (%s, %s, %s, 'follower', %s, %s, now() + interval '7 days')
                """,
                (baby_id, owner, email.upper() if status == "pending" else email,
                 uuid.uuid4().hex, status),
            )
        conn.execute(
            """
            INSERT INTO activity_events (baby_profile_id, actor_firebase_uid, event_type,
                                         summary, params, payload)
            VALUES (%s, %s, 'photo_comment', 'Mia commented on "Beach"', %s, NULL),
                   (%s, %s, 'member_removed', 'Owner removed Mia from the family', '{}', %s)
            """,
            (baby_id, member, Json({"caption": "Beach"}),
             baby_id, owner, Json({"target_firebase_uid": member})),
        )


def _assert_member_purged(owner: str, member: str) -> None:
    for table in ("notifications", "device_tokens", "announcement_dismissals",
                  "biometric_credentials"):
        assert _count(
            f"SELECT COUNT(*)::int AS n FROM {table} WHERE firebase_uid = %s", member
        ) == 0, table
    # Other people's inbox rows about the deleted member are gone too.
    assert _count(
        "SELECT COUNT(*)::int AS n FROM notifications WHERE actor_firebase_uid = %s", member
    ) == 0
    with get_connection() as conn:
        user = conn.execute(
            """
            SELECT display_name, email, avatar_url, phone, birth_date, country_code,
                   postal_code, last_seen_at, biometric_unlock_enabled, deleted_at
            FROM app_users WHERE firebase_uid = %s
            """,
            (member,),
        ).fetchone()
        summaries = [
            r["summary"]
            for r in conn.execute(
                """
                SELECT summary FROM activity_events
                WHERE actor_firebase_uid = %s OR payload->>'target_firebase_uid' = %s
                ORDER BY event_type
                """,
                (member, member),
            ).fetchall()
        ]
    assert user["display_name"] == "Deleted user"
    assert user["deleted_at"] is not None
    assert not user["biometric_unlock_enabled"]
    for column in ("email", "avatar_url", "phone", "birth_date", "country_code",
                   "postal_code", "last_seen_at"):
        assert user[column] is None, column
    assert summaries == [
        "Owner removed Deleted user from the family",
        'Deleted user commented on "Beach"',
    ]


def test_delete_account_purges_personal_rows_in_the_delete_transaction():
    owner, member = _uid("owner"), _uid("member")
    _user(owner, "Owner")
    email = _user(member, "Mia")
    baby_id = _shared_baby(owner, member)
    _seed_personal_rows(baby_id, owner, member, email)

    delete_account_rows(member)

    _assert_member_purged(owner, member)
    # The owner keeps the inbox row that is not about the deleted member.
    assert _count(
        "SELECT COUNT(*)::int AS n FROM notifications WHERE firebase_uid = %s", owner
    ) == 1
    # Settled invite history to their email is gone; the open invite stays.
    with get_connection() as conn:
        statuses = [
            r["status"]
            for r in conn.execute(
                "SELECT status FROM invitations WHERE lower(invitee_email) = lower(%s)",
                (email,),
            ).fetchall()
        ]
    assert statuses == ["pending"]


def _run_migration_046() -> None:
    with get_connection() as conn:
        with psycopg.ClientCursor(conn) as cur:
            cur.execute(_MIGRATION_046.read_text())


def test_migration_046_backfills_accounts_tombstoned_before_the_fix():
    owner, member = _uid("owner"), _uid("member")
    _user(owner, "Owner")
    email = _user(member, "Mia")
    baby_id = _shared_baby(owner, member)
    _seed_personal_rows(baby_id, owner, member, email)
    with get_connection() as conn:
        # What delete_account_rows did before #364.
        conn.execute(
            """
            UPDATE app_users
            SET display_name = 'Deleted user', email = NULL, avatar_url = NULL,
                deleted_at = now()
            WHERE firebase_uid = %s
            """,
            (member,),
        )

    _run_migration_046()
    _run_migration_046()  # idempotent

    _assert_member_purged(owner, member)


@pytest.mark.parametrize("event_type", [*ActivityEventType, "legacy_type"])
@pytest.mark.parametrize(
    "params",
    [
        {},
        {"caption": " Beach ", "item_name": "Crib", "event_title": "Shower",
         "suggested_name": "Ada", "gender": "girl", "baby_name": "Nora"},
    ],
)
def test_migration_046_summary_matches_activity_copy(event_type, params):
    owner, member = _uid("owner"), _uid("member")
    _user(owner, "Owner")
    _user(member, "Mia")
    baby_id = _shared_baby(owner, member)
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO activity_events (baby_profile_id, actor_firebase_uid, event_type,
                                         summary, params, payload)
            VALUES (%s, %s, %s, 'stale', %s, %s)
            """,
            (baby_id, member, str(event_type), Json(params),
             Json({"target_firebase_uid": owner})),
        )
        conn.execute(
            "UPDATE app_users SET display_name = 'Deleted user', deleted_at = now() "
            "WHERE firebase_uid = %s",
            (member,),
        )

    _run_migration_046()

    with get_connection() as conn:
        summary = conn.execute(
            "SELECT summary FROM activity_events WHERE actor_firebase_uid = %s", (member,)
        ).fetchone()["summary"]
    assert summary == activity_summary(
        str(event_type), params, actor="Deleted user", target="Owner"
    )
