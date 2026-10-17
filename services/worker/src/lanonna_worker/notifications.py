from __future__ import annotations

import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date
from typing import Any

import firebase_admin
from firebase_admin import messaging

from lanonna_worker.db import get_connection
from lanonna_worker.idempotency import resolve_delivery_key, try_claim_delivery
from lanonna_worker.notification_metadata import (
    GENERIC,
    actor_uid_from_payload,
    notification_type_from_payload,
)

logger = logging.getLogger("lanonna.worker.notifications")

_CHANNEL_COLUMNS: dict[str, str] = {
    "gallery": "notify_gallery_enabled",
    "calendar": "notify_calendar_enabled",
    "registry": "notify_registry_enabled",
    "comments": "notify_comments_enabled",
}

_fcm_initialized = False
_FCM_MULTICAST_LIMIT = 500


def _should_delete_fcm_token(exc: BaseException | None) -> bool:
    """Drop stale device tokens only for permanent registration failures."""
    if exc is None:
        return False
    if isinstance(
        exc,
        (
            messaging.UnregisteredError,
            messaging.SenderIdMismatchError,
        ),
    ):
        return True
    code = getattr(exc, "code", None)
    if isinstance(code, str) and code.upper() in {
        "NOT_FOUND",
        "UNREGISTERED",
        "INVALID_ARGUMENT",
    }:
        return True
    return False


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


@dataclass(frozen=True)
class _Recipient:
    """One inbox recipient with everything delivery needs, loaded in one query."""

    firebase_uid: str
    channel_enabled: bool
    realtime_push: bool
    fcm_tokens: tuple[str, ...]


def _load_recipients(
    conn: Any,
    firebase_uids: list[str],
    notification_channel: str | None,
) -> list[_Recipient]:
    """Channel opt-in, push preferences and device tokens for every recipient.

    One statement for the whole recipient list, so fan-out and digest runs do
    not issue per-user preference or token lookups. Tombstoned or unknown users
    are not returned. Order follows ``firebase_uids``.
    """
    if not firebase_uids:
        return []
    column = _CHANNEL_COLUMNS.get(notification_channel or "")
    channel_expr = f"u.{column}" if column else "true"
    rows = conn.execute(
        f"""
        SELECT
            u.firebase_uid,
            COALESCE({channel_expr}, true) AS channel_enabled,
            COALESCE(u.push_notifications_enabled, true)
                AND COALESCE(u.notification_digest, 'realtime') = 'realtime'
                AS realtime_push,
            tokens.fcm_tokens
        FROM app_users u
        CROSS JOIN LATERAL (
            SELECT COALESCE(
                array_agg(t.fcm_token ORDER BY t.fcm_token)
                    FILTER (WHERE t.fcm_token IS NOT NULL AND t.fcm_token <> ''),
                ARRAY[]::text[]
            ) AS fcm_tokens
            FROM device_tokens t
            WHERE t.firebase_uid = u.firebase_uid
        ) tokens
        WHERE u.firebase_uid = ANY(%s)
          AND u.deleted_at IS NULL
        """,
        (list(firebase_uids),),
    ).fetchall()
    by_uid = {
        row["firebase_uid"]: _Recipient(
            firebase_uid=row["firebase_uid"],
            channel_enabled=bool(row["channel_enabled"]),
            realtime_push=bool(row["realtime_push"]),
            fcm_tokens=tuple(row["fcm_tokens"] or ()),
        )
        for row in rows
    }
    return [by_uid[uid] for uid in dict.fromkeys(firebase_uids) if uid in by_uid]


def _insert_notifications(
    conn: Any,
    *,
    firebase_uids: list[str],
    title: str,
    body: str,
    deep_link: str | None,
    baby_profile_id: uuid.UUID | None,
    notification_type: str = GENERIC,
    actor_firebase_uid: str | None = None,
) -> dict[str, uuid.UUID]:
    """Write one inbox row per recipient in a single statement; uid -> row id."""
    if not firebase_uids:
        return {}
    ids = {uid: uuid.uuid4() for uid in firebase_uids}
    conn.execute(
        """
        INSERT INTO notifications (
            id, firebase_uid, baby_profile_id, title, body, deep_link,
            notification_type, actor_firebase_uid, actor_display_name
        )
        SELECT r.id, r.firebase_uid, %s, %s, %s, %s, %s, a.firebase_uid,
            NULLIF(TRIM(a.display_name), '')
        FROM unnest(%s::uuid[], %s::text[]) AS r(id, firebase_uid)
        LEFT JOIN app_users a ON a.firebase_uid = %s
        """,
        (
            baby_profile_id,
            title,
            body,
            deep_link,
            notification_type,
            list(ids.values()),
            list(ids.keys()),
            actor_firebase_uid,
        ),
    )
    return ids


def _delete_fcm_tokens(conn: Any, tokens: list[str]) -> None:
    conn.execute("DELETE FROM device_tokens WHERE fcm_token = ANY(%s)", (tokens,))


def _chunk_tokens(tokens: list[str], size: int = _FCM_MULTICAST_LIMIT) -> list[list[str]]:
    return [tokens[i : i + size] for i in range(0, len(tokens), size)]


def _prune_fcm_token_responses(
    conn: Any,
    tokens: list[str],
    response: messaging.BatchResponse,
    *,
    log_uid: str | None = None,
) -> None:
    stale: list[str] = []
    for idx, send_response in enumerate(response.responses):
        if send_response.success:
            continue
        exc = send_response.exception
        if exc is not None:
            logger.warning(
                "fcm_token_failed uid=%s error=%s",
                log_uid or "-",
                exc,
            )
        if idx < len(tokens) and _should_delete_fcm_token(exc):
            stale.append(tokens[idx])
    if stale:
        _delete_fcm_tokens(conn, stale)


def _send_multicast_and_prune_tokens(
    conn: Any,
    tokens: list[str],
    build_message: Callable[[list[str]], messaging.MulticastMessage],
    *,
    log_uid: str | None = None,
) -> None:
    if not tokens:
        return
    _ensure_fcm()
    for chunk in _chunk_tokens(tokens):
        message = build_message(chunk)
        try:
            response = messaging.send_each_for_multicast(message)
        except Exception:
            if log_uid:
                logger.exception("fcm_send_failed uid=%s", log_uid)
            else:
                logger.exception("fcm_send_failed")
            continue
        _prune_fcm_token_responses(conn, chunk, response, log_uid=log_uid)


def _send_push(
    conn: Any,
    *,
    firebase_uid: str,
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, str],
) -> None:
    def build_message(chunk: list[str]) -> messaging.MulticastMessage:
        return messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            tokens=chunk,
        )

    _send_multicast_and_prune_tokens(
        conn, tokens, build_message, log_uid=firebase_uid
    )


def _deliver_to_inbox_and_push(
    conn: Any,
    recipients: list[_Recipient],
    *,
    title: str,
    body: str,
    deep_link: str | None,
    baby_profile_id: uuid.UUID | None,
    notification_type: str,
    actor_firebase_uid: str | None,
) -> None:
    """Shared tail of notify-user and fan-out: inbox rows, then realtime push."""
    opted_in = [r for r in recipients if r.channel_enabled]
    notification_ids = _insert_notifications(
        conn,
        firebase_uids=[r.firebase_uid for r in opted_in],
        title=title,
        body=body,
        deep_link=deep_link,
        baby_profile_id=baby_profile_id,
        notification_type=notification_type,
        actor_firebase_uid=actor_firebase_uid,
    )
    for recipient in opted_in:
        if not recipient.realtime_push or not recipient.fcm_tokens:
            continue
        data: dict[str, str] = {
            "deep_link": deep_link or "/home",
            "notification_id": str(notification_ids[recipient.firebase_uid]),
        }
        if baby_profile_id is not None:
            data["baby_profile_id"] = str(baby_profile_id)
        _send_push(
            conn,
            firebase_uid=recipient.firebase_uid,
            tokens=list(recipient.fcm_tokens),
            title=title,
            body=body,
            data=data,
        )


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
    notification_type = notification_type_from_payload(payload)
    actor_firebase_uid = actor_uid_from_payload(payload)
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
        _deliver_to_inbox_and_push(
            conn,
            _load_recipients(conn, uids, channel),
            title=title,
            body=body,
            deep_link=deep_link,
            baby_profile_id=baby_id,
            notification_type=notification_type,
            actor_firebase_uid=actor_firebase_uid,
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
    notification_type = notification_type_from_payload(payload)
    actor_firebase_uid = actor_uid_from_payload(payload)
    delivery_key = resolve_delivery_key(payload, pubsub_message_id=pubsub_message_id)

    with get_connection() as conn:
        if delivery_key and not try_claim_delivery(conn, delivery_key):
            logger.info("notify_user_skip_duplicate key=%s", delivery_key)
            return
        _deliver_to_inbox_and_push(
            conn,
            _load_recipients(conn, [uid], channel),
            title=title,
            body=body,
            deep_link=deep_link,
            baby_profile_id=baby_id,
            notification_type=notification_type,
            actor_firebase_uid=actor_firebase_uid,
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
        if pubsub_message_id is None and not try_claim_delivery(
            conn, f"weekly_digest:http_cron:{date.today().isoformat()}"
        ):
            logger.info("weekly_digest_skip_http_cron_duplicate")
            return
        # Unread counts and device tokens are aggregated in the same statement
        # as the candidate users, so the run issues no per-user COUNT or token
        # query. Users without a device token are not candidates.
        rows = conn.execute(
            """
            SELECT u.firebase_uid, unread.n AS unread_count, tokens.fcm_tokens
            FROM app_users u
            JOIN LATERAL (
                SELECT COUNT(*)::int AS n
                FROM notifications n
                WHERE n.firebase_uid = u.firebase_uid
                  AND n.created_at >= now() - interval '7 days'
                  AND n.read_at IS NULL
            ) unread ON unread.n > 0
            JOIN LATERAL (
                SELECT array_agg(t.fcm_token ORDER BY t.fcm_token) AS fcm_tokens
                FROM device_tokens t
                WHERE t.firebase_uid = u.firebase_uid
                  AND t.fcm_token IS NOT NULL
                  AND t.fcm_token <> ''
            ) tokens ON tokens.fcm_tokens IS NOT NULL
            WHERE u.deleted_at IS NULL
              AND u.push_notifications_enabled = true
              AND u.notification_digest = 'weekly'
              AND (
                u.last_weekly_digest_at IS NULL
                OR u.last_weekly_digest_at < now() - interval '7 days'
              )
            """
        ).fetchall()

        sent_uids: list[str] = []
        for row in rows:
            uid = row["firebase_uid"]
            count = int(row["unread_count"])
            _send_push(
                conn,
                firebase_uid=uid,
                tokens=list(row["fcm_tokens"]),
                title="Your weekly update",
                body=(
                    f"You have {count} unread update{'s' if count != 1 else ''} "
                    "from La Nonna"
                ),
                data={"deep_link": "/notifications/inbox", "notification_id": ""},
            )
            sent_uids.append(uid)

        if sent_uids:
            conn.execute(
                """
                UPDATE app_users
                SET last_weekly_digest_at = now(), updated_at = now()
                WHERE firebase_uid = ANY(%s)
                """,
                (sent_uids,),
            )
