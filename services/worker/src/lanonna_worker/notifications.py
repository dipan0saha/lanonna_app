from __future__ import annotations

import logging
import uuid
from typing import Any

import firebase_admin
from firebase_admin import messaging

from lanonna_worker.db import get_connection
from lanonna_worker.idempotency import resolve_delivery_key, try_claim_delivery

logger = logging.getLogger("lanonna.worker.notifications")

_CHANNEL_COLUMNS: dict[str, str] = {
    "gallery": "notify_gallery_enabled",
    "calendar": "notify_calendar_enabled",
    "registry": "notify_registry_enabled",
    "comments": "notify_comments_enabled",
}

_fcm_initialized = False


def _ensure_fcm() -> None:
    global _fcm_initialized
    if _fcm_initialized:
        return
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    _fcm_initialized = True


def _resolve_recipient_uids(
    conn: Any,
    *,
    baby_profile_id: uuid.UUID,
    recipient_mode: str,
    exclude_firebase_uid: str | None,
    firebase_uids: list[str],
) -> list[str]:
    if recipient_mode == "firebase_uids":
        uids = [u for u in firebase_uids if u and u != exclude_firebase_uid]
        return list(dict.fromkeys(uids))

    if recipient_mode == "baby_owners":
        role_clause = "AND m.role = 'owner'"
    else:
        role_clause = ""

    rows = conn.execute(
        f"""
        SELECT m.firebase_uid
        FROM baby_memberships m
        JOIN app_users u ON u.firebase_uid = m.firebase_uid
        WHERE m.baby_profile_id = %s
          AND m.removed_at IS NULL
          AND u.deleted_at IS NULL
          {role_clause}
        """,
        (baby_profile_id,),
    ).fetchall()
    out: list[str] = []
    for row in rows:
        uid = row["firebase_uid"]
        if exclude_firebase_uid and uid == exclude_firebase_uid:
            continue
        out.append(uid)
    return out


def _insert_notification(
    conn: Any,
    *,
    firebase_uid: str,
    title: str,
    body: str,
    deep_link: str | None,
    baby_profile_id: uuid.UUID | None,
) -> uuid.UUID:
    notification_id = uuid.uuid4()
    conn.execute(
        """
        INSERT INTO notifications (
            id, firebase_uid, baby_profile_id, title, body, deep_link
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (notification_id, firebase_uid, baby_profile_id, title, body, deep_link),
    )
    return notification_id


def _user_channel_enabled(
    conn: Any, firebase_uid: str, notification_channel: str | None
) -> bool:
    if not notification_channel:
        return True
    column = _CHANNEL_COLUMNS.get(notification_channel)
    if column is None:
        return True
    row = conn.execute(
        f"""
        SELECT {column} AS enabled
        FROM app_users
        WHERE firebase_uid = %s AND deleted_at IS NULL
        """,
        (firebase_uid,),
    ).fetchone()
    if row is None:
        return False
    return bool(row.get("enabled", True))


def _user_push_prefs(conn: Any, firebase_uid: str) -> tuple[bool, str]:
    row = conn.execute(
        """
        SELECT push_notifications_enabled, notification_digest
        FROM app_users
        WHERE firebase_uid = %s AND deleted_at IS NULL
        """,
        (firebase_uid,),
    ).fetchone()
    if row is None:
        return False, "realtime"
    push_on = bool(row.get("push_notifications_enabled", True))
    digest = row.get("notification_digest") or "realtime"
    return push_on, digest


def _list_fcm_tokens(conn: Any, firebase_uid: str) -> list[str]:
    rows = conn.execute(
        """
        SELECT fcm_token FROM device_tokens WHERE firebase_uid = %s
        """,
        (firebase_uid,),
    ).fetchall()
    return [r["fcm_token"] for r in rows if r.get("fcm_token")]


def _delete_fcm_token(conn: Any, token: str) -> None:
    conn.execute("DELETE FROM device_tokens WHERE fcm_token = %s", (token,))


def _send_fcm(
    conn: Any,
    *,
    firebase_uid: str,
    title: str,
    body: str,
    deep_link: str | None,
    notification_id: uuid.UUID,
    baby_profile_id: uuid.UUID | None = None,
) -> None:
    push_on, digest = _user_push_prefs(conn, firebase_uid)
    if not push_on or digest != "realtime":
        return

    tokens = _list_fcm_tokens(conn, firebase_uid)
    if not tokens:
        return

    _ensure_fcm()
    data: dict[str, str] = {
        "deep_link": deep_link or "/home",
        "notification_id": str(notification_id),
    }
    if baby_profile_id is not None:
        data["baby_profile_id"] = str(baby_profile_id)
    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=data,
        tokens=tokens,
    )
    try:
        response = messaging.send_each_for_multicast(message)
    except Exception:
        logger.exception("fcm_send_failed uid=%s", firebase_uid)
        return

    for idx, send_response in enumerate(response.responses):
        if send_response.success:
            continue
        exc = send_response.exception
        if exc is not None:
            logger.warning(
                "fcm_token_failed uid=%s error=%s",
                firebase_uid,
                exc,
            )
        if idx < len(tokens):
            _delete_fcm_token(conn, tokens[idx])


def process_notify_fan_out(
    payload: dict[str, Any],
    *,
    pubsub_message_id: str | None = None,
) -> None:
    baby_id = uuid.UUID(str(payload["baby_profile_id"]))
    title = str(payload["title"])
    body = str(payload["body"])
    deep_link = payload.get("deep_link")
    recipient_mode = str(payload.get("recipient_mode") or "baby_members")
    exclude = payload.get("exclude_firebase_uid")
    explicit_uids = [str(u) for u in payload.get("firebase_uids") or []]
    channel = payload.get("notification_channel")
    delivery_key = resolve_delivery_key(payload, pubsub_message_id=pubsub_message_id)

    with get_connection() as conn:
        if delivery_key and not try_claim_delivery(conn, delivery_key):
            logger.info("notify_fan_out_skip_duplicate key=%s", delivery_key)
            return
        uids = _resolve_recipient_uids(
            conn,
            baby_profile_id=baby_id,
            recipient_mode=recipient_mode,
            exclude_firebase_uid=exclude,
            firebase_uids=explicit_uids,
        )
        for uid in uids:
            if not _user_channel_enabled(conn, uid, channel):
                continue
            nid = _insert_notification(
                conn,
                firebase_uid=uid,
                title=title,
                body=body,
                deep_link=deep_link,
                baby_profile_id=baby_id,
            )
            _send_fcm(
                conn,
                firebase_uid=uid,
                title=title,
                body=body,
                deep_link=deep_link,
                notification_id=nid,
                baby_profile_id=baby_id,
            )


def process_notify_user(
    payload: dict[str, Any],
    *,
    pubsub_message_id: str | None = None,
) -> None:
    uid = str(payload["firebase_uid"])
    title = str(payload["title"])
    body = str(payload["body"])
    deep_link = payload.get("deep_link")
    baby_raw = payload.get("baby_profile_id")
    baby_id = uuid.UUID(str(baby_raw)) if baby_raw else None
    channel = payload.get("notification_channel")
    delivery_key = resolve_delivery_key(payload, pubsub_message_id=pubsub_message_id)

    with get_connection() as conn:
        if delivery_key and not try_claim_delivery(conn, delivery_key):
            logger.info("notify_user_skip_duplicate key=%s", delivery_key)
            return
        if not _user_channel_enabled(conn, uid, channel):
            return
        nid = _insert_notification(
            conn,
            firebase_uid=uid,
            title=title,
            body=body,
            deep_link=deep_link,
            baby_profile_id=baby_id,
        )
        _send_fcm(
            conn,
            firebase_uid=uid,
            title=title,
            body=body,
            deep_link=deep_link,
            notification_id=nid,
            baby_profile_id=baby_id,
        )


def process_weekly_notification_digest(
    *,
    pubsub_message_id: str | None = None,
) -> None:
    with get_connection() as conn:
        if pubsub_message_id and not try_claim_delivery(
            conn, f"pubsub:{pubsub_message_id}"
        ):
            logger.info("weekly_digest_skip_duplicate message_id=%s", pubsub_message_id)
            return
        rows = conn.execute(
            """
            SELECT firebase_uid
            FROM app_users
            WHERE deleted_at IS NULL
              AND push_notifications_enabled = true
              AND notification_digest = 'weekly'
              AND (
                last_weekly_digest_at IS NULL
                OR last_weekly_digest_at < now() - interval '7 days'
              )
            """
        ).fetchall()

        for row in rows:
            uid = row["firebase_uid"]
            count_row = conn.execute(
                """
                SELECT COUNT(*)::int AS n
                FROM notifications
                WHERE firebase_uid = %s
                  AND created_at >= now() - interval '7 days'
                  AND read_at IS NULL
                """,
                (uid,),
            ).fetchone()
            count = int(count_row["n"]) if count_row else 0
            if count <= 0:
                continue

            title = "Your weekly update"
            body = (
                f"You have {count} unread update{'s' if count != 1 else ''} from La Nonna"
            )
            deep_link = "/notifications/inbox"
            tokens = _list_fcm_tokens(conn, uid)
            if not tokens:
                continue

            _ensure_fcm()
            data = {"deep_link": deep_link, "notification_id": ""}
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data=data,
                tokens=tokens,
            )
            try:
                response = messaging.send_each_for_multicast(message)
                for idx, send_response in enumerate(response.responses):
                    if not send_response.success and idx < len(tokens):
                        _delete_fcm_token(conn, tokens[idx])
            except Exception:
                logger.exception("weekly_digest_fcm_failed uid=%s", uid)
                continue

            conn.execute(
                """
                UPDATE app_users
                SET last_weekly_digest_at = now(), updated_at = now()
                WHERE firebase_uid = %s
                """,
                (uid,),
            )
