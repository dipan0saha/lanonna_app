import base64
import json
import logging
from typing import Any

from fastapi import FastAPI, Request, Response

import uuid

from lanonna_worker.config import settings, validate_worker_settings

validate_worker_settings()
from lanonna_worker.baby_data_export import run_baby_data_export
from lanonna_worker.invite_email import send_invite_email
from lanonna_worker.notifications import (
    process_notify_fan_out,
    process_notify_user,
    process_weekly_notification_digest,
)
from lanonna_worker.invite_cleanup import expire_stale_pending_invitations
from lanonna_worker.thumbnails import process_gcs_finalize

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("lanonna.worker")

app = FastAPI(title="La Nonna Worker", version="0.1.0")


def _safe_payload_summary(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": payload.get("type"),
        "keys": sorted(payload.keys()),
    }


def _delivery_attempt(body: dict[str, Any]) -> int | None:
    """Pub/Sub ``deliveryAttempt`` (1-based); present when the subscription has a DLQ policy."""
    raw = body.get("deliveryAttempt")
    return raw if isinstance(raw, int) and not isinstance(raw, bool) and raw > 0 else None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.post("/cron/expire-pending-invitations")
async def cron_expire_pending_invitations() -> Response:
    """Cloud Scheduler (OIDC): mark expired pending invitations."""
    try:
        expire_stale_pending_invitations()
    except Exception:
        logger.exception("cron_expire_pending_invitations_failed")
        return Response(status_code=500)
    return Response(status_code=204)


@app.post("/cron/weekly-notification-digest")
async def cron_weekly_notification_digest() -> Response:
    """Invoked by Cloud Scheduler (OIDC) to enqueue weekly digest pushes."""
    try:
        process_weekly_notification_digest()
    except Exception:
        logger.exception("cron_weekly_notification_digest_failed")
        return Response(status_code=500)
    return Response(status_code=204)


@app.post("/pubsub/push")
async def pubsub_push(request: Request) -> Response:
    """Pub/Sub push: thumbnails, invite email, notifications, exports, invite expiry."""
    body: dict[str, Any] = await request.json()
    message = body.get("message", {})
    pubsub_message_id = message.get("messageId")
    raw = message.get("data", "")
    payload: dict[str, Any] = {}
    if raw:
        try:
            payload = json.loads(base64.b64decode(raw).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            payload = {"raw": raw}
    if payload.get("type") == "send_invite_email":
        invitation_id_raw = payload.get("invitation_id")
        if not invitation_id_raw:
            logger.warning("send_invite_email missing fields message_id=%s", message.get("messageId"))
            return Response(status_code=204)
        try:
            send_invite_email(uuid.UUID(str(invitation_id_raw)))
        except Exception:
            logger.exception("send_invite_email_failed invitation_id=%s", invitation_id_raw)
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "notify_fan_out":
        try:
            process_notify_fan_out(payload, pubsub_message_id=pubsub_message_id)
        except Exception:
            logger.exception("notify_fan_out_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "notify_user":
        try:
            process_notify_user(payload, pubsub_message_id=pubsub_message_id)
        except Exception:
            logger.exception("notify_user_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "expire_pending_invitations":
        try:
            expire_stale_pending_invitations()
        except Exception:
            logger.exception(
                "expire_pending_invitations_failed message_id=%s",
                message.get("messageId"),
            )
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "weekly_notification_digest":
        try:
            process_weekly_notification_digest(pubsub_message_id=pubsub_message_id)
        except Exception:
            logger.exception("weekly_notification_digest_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "baby_data_export":
        job_id_raw = payload.get("job_id")
        if not job_id_raw:
            logger.warning("baby_data_export missing job_id message_id=%s", message.get("messageId"))
            return Response(status_code=204)
        # The job row is the idempotency guard; do not dedupe on messageId or retries
        # after a failure would be acked without running (H-09).
        delivery_attempt = _delivery_attempt(body)
        try:
            run_baby_data_export(
                uuid.UUID(str(job_id_raw)),
                redelivery=delivery_attempt is not None and delivery_attempt > 1,
                final_attempt=(
                    delivery_attempt is None
                    or delivery_attempt >= settings.pubsub_max_delivery_attempts
                ),
            )
        except Exception:
            logger.exception("baby_data_export_failed job_id=%s", job_id_raw)
            return Response(status_code=500)
        return Response(status_code=204)

    bucket = payload.get("bucket")
    name = payload.get("name")
    if bucket and name:
        logger.info(
            "gcs_object_finalized message_id=%s bucket=%s name=%s",
            message.get("messageId"),
            bucket,
            name,
        )
        try:
            process_gcs_finalize(payload)
        except Exception:
            logger.exception("thumbnail_processing_failed name=%s", name)
            return Response(status_code=500)
    else:
        logger.info(
            "pubsub message_id=%s subscription=%s payload=%s",
            message.get("messageId"),
            body.get("subscription"),
            _safe_payload_summary(payload),
        )
    return Response(status_code=204)
