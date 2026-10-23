"""Account delete removes personal SQL rows that tombstone bypasses (issue #364)."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.account_delete import delete_account_rows
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(uid: str) -> None:
    resolve_app_user(uid, f"{uid}@example.com")


def _count(sql: str, *params: object) -> int:
    with get_connection() as conn:
        row = conn.execute(sql, params).fetchone()
    return int(row["n"])


def test_delete_account_purges_inbox_device_tokens_and_anonymizes_actor():
    recipient = "inbox-recipient"
    actor = "inbox-actor-delete"
    _user(recipient)
    _user(actor)
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Nora', 'expecting', %s)
            """,
            (baby_id, recipient),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, recipient),
        )
        conn.execute(
            """
            INSERT INTO notifications (
                firebase_uid, baby_profile_id, title, body,
                notification_type, actor_firebase_uid, actor_display_name
            )
            VALUES (%s, %s, 'New comment', 'body', 'comment', %s, 'Actor Name')
            """,
            (recipient, baby_id, actor),
        )
        conn.execute(
            """
            INSERT INTO notifications (firebase_uid, title, body, notification_type)
            VALUES (%s, 'Digest', 'yours', 'digest')
            """,
            (actor,),
        )
        conn.execute(
            """
            INSERT INTO device_tokens (firebase_uid, fcm_token, platform)
            VALUES (%s, 'token-actor', 'ios')
            """,
            (actor,),
        )
        ann_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO system_announcements (id, title, body, priority)
            VALUES (%s, 'Hello', 'World', 0)
            """,
            (ann_id,),
        )
        conn.execute(
            """
            INSERT INTO announcement_dismissals (announcement_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (ann_id, actor),
        )
        conn.execute(
            """
            INSERT INTO biometric_credentials (
                firebase_uid, device_id, public_key_pem, algorithm
            )
            VALUES (%s, 'dev-1', 'pem', 'ecdsa_p256_sha256')
            """,
            (actor,),
        )

    delete_account_rows(actor)

    assert (
        _count(
            "SELECT COUNT(*)::int AS n FROM notifications WHERE firebase_uid = %s",
            actor,
        )
        == 0
    )
    assert (
        _count(
            "SELECT COUNT(*)::int AS n FROM device_tokens WHERE firebase_uid = %s",
            actor,
        )
        == 0
    )
    assert (
        _count(
            """
            SELECT COUNT(*)::int AS n FROM announcement_dismissals
            WHERE firebase_uid = %s
            """,
            actor,
        )
        == 0
    )
    assert (
        _count(
            """
            SELECT COUNT(*)::int AS n FROM biometric_credentials
            WHERE firebase_uid = %s
            """,
            actor,
        )
        == 0
    )
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT actor_firebase_uid, actor_display_name
            FROM notifications
            WHERE firebase_uid = %s
            LIMIT 1
            """,
            (recipient,),
        ).fetchone()
    assert row["actor_firebase_uid"] is None
    assert row["actor_display_name"] is None
