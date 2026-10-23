import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Request, Response

from lanonna_worker.config import settings, validate_worker_settings

validate_worker_settings()
from lanonna_worker.baby_data_export import run_baby_data_export
from lanonna_worker.storage_cleanup import (
    run_storage_cleanup,
    sweep_storage_cleanup_jobs,
)
from lanonna_worker.invite_email import InviteSendOutcome, send_invite_email
from lanonna_worker.notifications import (
    process_notify_fan_out,
    process_notify_user,
    process_weekly_notification_digest,
)
from lanonna_worker.invite_cleanup import expire_stale_pending_invitations
from lanonna_worker.event_cover_cleanup import purge_stale_unreferenced_event_covers
from lanonna_worker.mailjet_send import mailjet_egress
from lanonna_worker.pubsub_payload import (
    decode_pubsub_data,
    parse_uuid_field,
    validate_notify_fan_out_payload,
    validate_notify_user_payload,
)
from lanonna_worker import db
from lanonna_worker.thumbnails import process_gcs_finalize

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("lanonna.worker")



@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Open the DB pool before the first push and close it on shutdown."""
    if settings.db_password:
        db.open_pool()
    try:
        yield
    finally:
        db.close_pool()


app = FastAPI(title="La Nonna Worker", version="0.1.0", lifespan=lifespan)


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


@app.get("/health/live")
def health_live() -> Response:
    """Cloud Run liveness probe (#428).

    Returns 503 when this instance has sustained connect-stage failures to Mailjet,
    so Cloud Run replaces it. Cloud Run reserves some paths ending in `z`
    (such as `/healthz`), so this path doesn't end in one.
    """
    reason = mailjet_egress.unhealthy_reason()
    if reason is None:
        return Response(status_code=200)
    logger.error("egress_unhealthy %s", reason)
    return Response(status_code=503)


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
    """Pub/Sub push: thumbnails, invite email, notifications, exports, invite expiry,
    storage cleanup."""
    body: dict[str, Any] = await request.json()
    message = body.get("message", {})
    pubsub_message_id = message.get("messageId")
    payload = decode_pubsub_data(message.get("data", ""))

    if payload.get("type") == "send_invite_email":
        invitation_id_raw = payload.get("invitation_id")
        if not invitation_id_raw:
            logger.warning(
                "send_invite_email missing fields message_id=%s",
                message.get("messageId"),
            )
            return Response(status_code=204)
        invitation_id = parse_uuid_field("invitation_id", invitation_id_raw)
        if invitation_id is None:
            return Response(status_code=204)
        delivery_attempt = _delivery_attempt(body)
        try:
            outcome = send_invite_email(
                invitation_id,
                delivery_attempt=delivery_attempt,
                final_attempt=(
                    delivery_attempt is None
                    or delivery_attempt >= settings.pubsub_max_delivery_attempts
                ),
            )
        except Exception:
            logger.exception(
                "send_invite_email_failed invitation_id=%s",
                invitation_id_raw,
            )
            return Response(status_code=500)
        if outcome == InviteSendOutcome.RETRY:
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "notify_fan_out":
        if not validate_notify_fan_out_payload(payload):
            return Response(status_code=204)
        try:
            process_notify_fan_out(payload, pubsub_message_id=pubsub_message_id)
        except Exception:
            logger.exception("notify_fan_out_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "notify_user":
        if not validate_notify_user_payload(payload):
            return Response(status_code=204)
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

    if payload.get("type") == "sweep_storage_cleanup_jobs":
        try:
            sweep_storage_cleanup_jobs()
        except Exception:
            logger.exception("sweep_storage_cleanup_jobs_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "purge_stale_event_covers":
        try:
            purge_stale_unreferenced_event_covers()
        except Exception:
            logger.exception("purge_stale_event_covers_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "storage_cleanup":
        job_id_raw = payload.get("job_id")
        if not job_id_raw:
            logger.warning(
                "storage_cleanup missing job_id message_id=%s",
                message.get("messageId"),
            )
            return Response(status_code=204)
        job_id = parse_uuid_field("job_id", job_id_raw)
        if job_id is None:
            return Response(status_code=204)
        delivery_attempt = _delivery_attempt(body)
        try:
            run_storage_cleanup(
                job_id,
                redelivery=delivery_attempt is not None and delivery_attempt > 1,
                final_attempt=(
                    delivery_attempt is None
                    or delivery_attempt >= settings.pubsub_max_delivery_attempts
                ),
            )
        except Exception:
            logger.exception("storage_cleanup_failed job_id=%s", job_id_raw)
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "baby_data_export":
        job_id_raw = payload.get("job_id")
        if not job_id_raw:
            logger.warning(
                "baby_data_export missing job_id message_id=%s",
                message.get("messageId"),
            )
            return Response(status_code=204)
        job_id = parse_uuid_field("job_id", job_id_raw)
        if job_id is None:
            return Response(status_code=204)
        # The job row is the idempotency guard; do not dedupe on messageId or retries
        # after a failure would be acked without running (H-09).
        delivery_attempt = _delivery_attempt(body)
        try:
            run_baby_data_export(
                job_id,
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
