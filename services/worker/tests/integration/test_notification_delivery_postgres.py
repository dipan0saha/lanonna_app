"""Fan-out, notify-user and weekly digest delivery against real Postgres.

Recipient preferences and device tokens load in one statement for the whole
recipient list; inbox rows insert in one statement; the digest marks every
recipient in one UPDATE.
"""

from __future__ import annotations

import uuid
from unittest.mock import patch

from lanonna_worker import notifications
from lanonna_worker.db import get_connection


def _user(uid: str, **prefs) -> str:
    columns = ["firebase_uid", "email", *prefs]
    values = [uid, f"{uid}@example.test", *prefs.values()]
    placeholders = ", ".join(["%s"] * len(values))
    with get_connection() as conn:
        conn.execute(
            f"INSERT INTO app_users ({', '.join(columns)}) VALUES ({placeholders})",
            values,
        )
    return uid


def _tokens(uid: str, *tokens: str) -> None:
    with get_connection() as conn:
        for token in tokens:
            conn.execute(
                "INSERT INTO device_tokens (firebase_uid, fcm_token, platform)"
                " VALUES (%s, %s, 'android')",
                (uid, token),
            )


def _baby(owner: str, followers: list[str]) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, 'Parker', 'expecting', %s)",
            (baby_id, owner),
        )
        conn.execute(
            "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
            " VALUES (%s, %s, 'owner', 'created')",
            (baby_id, owner),
        )
        for uid in followers:
            conn.execute(
                "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
                " VALUES (%s, %s, 'follower', 'invite')",
                (baby_id, uid),
            )
    return baby_id


def test_load_recipients_reads_prefs_and_tokens_for_everyone_at_once():
    on = _user("on")
    muted = _user("muted", notify_gallery_enabled=False)
    weekly = _user("weekly", notification_digest="weekly")
    no_push = _user("nopush", push_notifications_enabled=False)
    gone = _user("gone")
    _tokens(on, "on-b", "on-a")
    _tokens(weekly, "weekly-a")
    with get_connection() as conn:
        conn.execute("UPDATE app_users SET deleted_at = now() WHERE firebase_uid = %s", (gone,))

        recipients = notifications._load_recipients(
            conn, [weekly, on, muted, no_push, gone, "unknown", on], "gallery"
        )
        any_channel = notifications._load_recipients(conn, [muted], None)

    assert [r.firebase_uid for r in recipients] == [weekly, on, muted, no_push]
    by_uid = {r.firebase_uid: r for r in recipients}
    assert by_uid[on].fcm_tokens == ("on-a", "on-b")
    assert by_uid[on].channel_enabled and by_uid[on].realtime_push
    assert by_uid[muted].channel_enabled is False and by_uid[muted].fcm_tokens == ()
    assert by_uid[weekly].realtime_push is False
    assert by_uid[no_push].realtime_push is False
    assert any_channel[0].channel_enabled is True


def test_fan_out_writes_inbox_rows_and_pushes_with_their_ids():
    owner = _user("owner", display_name="Sarah")
    on, muted, weekly = _user("f-on"), _user("f-muted", notify_gallery_enabled=False), _user(
        "f-weekly", notification_digest="weekly"
    )
    _tokens(on, "tok-on")
    _tokens(weekly, "tok-weekly")
    baby_id = _baby(owner, [on, muted, weekly])
    pushes: list[dict] = []

    def fake_push(conn, *, firebase_uid, tokens, title, body, data):
        pushes.append(
            {"uid": firebase_uid, "tokens": tokens, "title": title, "body": body, "data": data}
        )

    with patch.object(notifications, "_send_push", side_effect=fake_push):
        notifications.process_notify_fan_out(
            {
                "baby_profile_id": str(baby_id),
                "kind": "photo_commented",
                "params": {"caption": "Nursery"},
                "exclude_firebase_uid": owner,
                "notification_channel": "gallery",
                "actor_firebase_uid": owner,
            },
            pubsub_message_id=f"msg-{uuid.uuid4()}",
        )

    with get_connection() as conn:
        rows = conn.execute(
            "SELECT id, firebase_uid, actor_display_name, notification_type,"
            " notification_kind, params, title FROM notifications ORDER BY firebase_uid"
        ).fetchall()
    assert {r["firebase_uid"] for r in rows} == {on, weekly}
    assert {r["actor_display_name"] for r in rows} == {"Sarah"}
    assert {r["notification_type"] for r in rows} == {"comment"}
    assert {r["notification_kind"] for r in rows} == {"photo_commented"}
    assert all(r["params"] == {"caption": "Nursery"} for r in rows)
    assert {r["title"] for r in rows} == {"New comment"}
    inbox_id = next(r["id"] for r in rows if r["firebase_uid"] == on)
    assert pushes == [
        {
            "uid": on,
            "tokens": ["tok-on"],
            "title": "New comment",
            "body": "Sarah commented on your photo",
            "data": {
                "deep_link": "/home",
                "notification_id": str(inbox_id),
                "baby_profile_id": str(baby_id),
            },
        }
    ]


def test_stale_tokens_are_pruned_in_one_delete():
    uid = _user("prune")
    _tokens(uid, "keep", "drop")
    with get_connection() as conn:
        notifications._delete_fcm_tokens(conn, ["drop", "missing"])
        left = conn.execute("SELECT fcm_token FROM device_tokens").fetchall()
    assert [r["fcm_token"] for r in left] == ["keep"]


def test_weekly_digest_sends_to_token_holders_and_marks_them_once():
    with_tokens = _user("d-tokens", notification_digest="weekly")
    no_tokens = _user("d-none", notification_digest="weekly")
    realtime = _user("d-realtime")
    _tokens(with_tokens, "d1", "d2")
    _tokens(realtime, "r1")
    with get_connection() as conn:
        for uid in (with_tokens, no_tokens, realtime):
            conn.execute(
                "INSERT INTO notifications (firebase_uid, title, body) VALUES (%s, 't', 'b')",
                (uid,),
            )
    sent: list[tuple[str, list[str]]] = []

    def fake_push(conn, *, firebase_uid, tokens, title, body, data):
        sent.append((firebase_uid, tokens))

    with patch.object(notifications, "_send_push", side_effect=fake_push):
        notifications.process_weekly_notification_digest(
            pubsub_message_id=f"digest-{uuid.uuid4()}"
        )

    assert sent == [(with_tokens, ["d1", "d2"])]
    with get_connection() as conn:
        marked = conn.execute(
            "SELECT firebase_uid FROM app_users WHERE last_weekly_digest_at IS NOT NULL"
        ).fetchall()
    assert [r["firebase_uid"] for r in marked] == [with_tokens]


def test_notify_user_without_display_name_uses_neutral_actor_and_null_name():
    owner = _user("owner")
    actor = _user("actor")
    pushes: list[tuple[str, str]] = []

    def fake_push(conn, *, firebase_uid, tokens, title, body, data):
        pushes.append((title, body))

    _tokens(owner, "tok-owner")
    with patch.object(notifications, "_send_push", side_effect=fake_push):
        notifications.process_notify_user(
            {
                "firebase_uid": owner,
                "kind": "event_rsvp",
                "params": {"event_title": "Shower", "rsvp_status": "cant_go"},
                "actor_firebase_uid": actor,
                "notification_channel": "calendar",
            },
            pubsub_message_id=f"msg-{uuid.uuid4()}",
        )

    with get_connection() as conn:
        row = conn.execute(
            "SELECT actor_display_name, notification_kind, params FROM notifications"
            " WHERE firebase_uid = %s",
            (owner,),
        ).fetchone()
    assert row["actor_display_name"] is None
    assert row["notification_kind"] == "event_rsvp"
    assert row["params"] == {"event_title": "Shower", "rsvp_status": "cant_go"}
    assert pushes == [("New RSVP", 'Someone can\'t make it to "Shower"')]
