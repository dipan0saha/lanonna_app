from __future__ import annotations

import base64
import binascii
import json
import logging
import uuid
from typing import Any

from lanonna_activity_copy import NotificationKind, notification_kind_from_payload

logger = logging.getLogger("lanonna.worker.pubsub")

# Kinds that write an inbox row (the weekly digest is push-only).
INBOX_NOTIFICATION_KINDS = frozenset(NotificationKind) - {NotificationKind.WEEKLY_DIGEST}


def decode_pubsub_data(raw: Any) -> dict[str, Any]:
    """Decode Pub/Sub message ``data``; permanent failures return ``{}`` (caller should ack)."""
    if not raw:
        return {}
    if not isinstance(raw, str):
        logger.warning("pubsub_payload_permanent_reject reason=non_string_data")
        return {}
    try:
        decoded = base64.b64decode(raw, validate=True)
    except (binascii.Error, ValueError) as exc:
        logger.warning(
            "pubsub_payload_permanent_reject reason=invalid_base64 error=%s",
            exc,
        )
        return {}
    try:
        text = decoded.decode("utf-8")
    except UnicodeDecodeError as exc:
        logger.warning(
            "pubsub_payload_permanent_reject reason=invalid_utf8 error=%s",
            exc,
        )
        return {}
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        logger.warning(
            "pubsub_payload_permanent_reject reason=invalid_json error=%s",
            exc,
        )
        return {}
    if not isinstance(parsed, dict):
        logger.warning(
            "pubsub_payload_permanent_reject reason=not_object type=%s",
            type(parsed).__name__,
        )
        return {}
    return parsed


def parse_uuid_field(field: str, raw: Any) -> uuid.UUID | None:
    try:
        return uuid.UUID(str(raw))
    except (ValueError, AttributeError, TypeError):
        logger.warning(
            "pubsub_payload_permanent_reject reason=invalid_uuid field=%s",
            field,
        )
        return None


def _valid_notification_message(payload: dict[str, Any], payload_type: str) -> bool:
    """A notify payload names an inbox ``kind`` and optional ``params`` object.

    Payloads without a known kind (e.g. the pre-038 ``title``/``body`` shape)
    are permanent rejects: the worker never delivers server-written copy.
    """
    kind = notification_kind_from_payload(payload.get("kind"))
    if kind is None or kind not in INBOX_NOTIFICATION_KINDS:
        logger.warning(
            "pubsub_payload_permanent_reject reason=invalid_kind type=%s",
            payload_type,
        )
        return False
    if not isinstance(payload.get("params", {}), dict):
        logger.warning(
            "pubsub_payload_permanent_reject reason=invalid_params type=%s",
            payload_type,
        )
        return False
    return True


def validate_notify_fan_out_payload(payload: dict[str, Any]) -> bool:
    if "baby_profile_id" not in payload:
        logger.warning(
            "pubsub_payload_permanent_reject reason=missing_field field=baby_profile_id type=notify_fan_out"
        )
        return False
    if parse_uuid_field("baby_profile_id", payload["baby_profile_id"]) is None:
        return False
    return _valid_notification_message(payload, "notify_fan_out")


def validate_notify_user_payload(payload: dict[str, Any]) -> bool:
    uid = payload.get("firebase_uid")
    if not uid or not str(uid).strip():
        logger.warning(
            "pubsub_payload_permanent_reject reason=missing_field field=firebase_uid type=notify_user"
        )
        return False
    baby_raw = payload.get("baby_profile_id")
    if baby_raw is not None and parse_uuid_field("baby_profile_id", baby_raw) is None:
        return False
    return _valid_notification_message(payload, "notify_user")
