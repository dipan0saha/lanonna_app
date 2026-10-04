import base64
import json
import logging
from typing import Any

from fastapi import FastAPI, Request, Response

import uuid

from lanonna_worker.config import settings
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
    """Pub/Sub push delivery stub (ack by returning 2xx)."""
    body: dict[str, Any] = await request.json()
    message = body.get("message", {})
    raw = message.get("data", "")
    payload: dict[str, Any] = {}
    if raw:
        try:
            payload = json.loads(base64.b64decode(raw).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            payload = {"raw": raw}
    if payload.get("type") == "send_invite_email":
        invitation_id_raw = payload.get("invitation_id")
        invite_token = payload.get("invite_token")
        if not invitation_id_raw or not invite_token:
            logger.warning("send_invite_email missing fields message_id=%s", message.get("messageId"))
            return Response(status_code=204)
        try:
            send_invite_email(uuid.UUID(str(invitation_id_raw)), str(invite_token))
        except Exception:
            logger.exception("send_invite_email_failed invitation_id=%s", invitation_id_raw)
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "notify_fan_out":
        try:
            process_notify_fan_out(payload)
        except Exception:
            logger.exception("notify_fan_out_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "notify_user":
        try:
            process_notify_user(payload)
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
            process_weekly_notification_digest()
        except Exception:
            logger.exception("weekly_notification_digest_failed")
            return Response(status_code=500)
        return Response(status_code=204)

    if payload.get("type") == "baby_data_export":
        job_id_raw = payload.get("job_id")
        if not job_id_raw:
            logger.warning("baby_data_export missing job_id message_id=%s", message.get("messageId"))
            return Response(status_code=204)
        try:
            run_baby_data_export(uuid.UUID(str(job_id_raw)))
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
            payload,
        )
    return Response(status_code=204)
