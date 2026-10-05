from __future__ import annotations

import json
import logging
import uuid

from google.cloud import pubsub_v1

from lanonna_api.config import settings

logger = logging.getLogger("lanonna.api.pubsub")

_publisher: pubsub_v1.PublisherClient | None = None


def _publisher_client() -> pubsub_v1.PublisherClient:
    global _publisher
    if _publisher is None:
        _publisher = pubsub_v1.PublisherClient()
    return _publisher


def _publish_commands_payload(payload: dict) -> None:
    topic_path = _publisher_client().topic_path(
        settings.gcp_project_id,
        settings.pubsub_topic_commands,
    )
    data = json.dumps(payload).encode("utf-8")
    future = _publisher_client().publish(topic_path, data)
    future.result(timeout=30)


def publish_send_invite_email(invitation_id: uuid.UUID, invite_token: str) -> None:
    payload = {
        "type": "send_invite_email",
        "invitation_id": str(invitation_id),
        "invite_token": invite_token,
    }
    if settings.invite_email_publish_disabled:
        logger.info(
            "invite_email_publish_skipped invitation_id=%s (INVITE_EMAIL_PUBLISH_DISABLED)",
            invitation_id,
        )
        return

    _publish_commands_payload(payload)


def publish_baby_data_export(job_id: uuid.UUID) -> None:
    payload = {
        "type": "baby_data_export",
        "job_id": str(job_id),
    }
    _publish_commands_payload(payload)


def _publish_worker_payload(payload: dict) -> None:
    if settings.notify_publish_disabled and payload.get("type") in (
        "notify_fan_out",
        "notify_user",
    ):
        logger.info(
            "notify_publish_skipped type=%s (NOTIFY_PUBLISH_DISABLED)",
            payload.get("type"),
        )
        return
    _publish_commands_payload(payload)


def publish_notify_fan_out(
    *,
    baby_profile_id: uuid.UUID,
    title: str,
    body: str,
    deep_link: str,
    recipient_mode: str,
    exclude_firebase_uid: str | None,
    firebase_uids: list[str],
    notification_channel: str | None = None,
) -> None:
    payload = {
        "type": "notify_fan_out",
        "baby_profile_id": str(baby_profile_id),
        "title": title,
        "body": body,
        "deep_link": deep_link,
        "recipient_mode": recipient_mode,
        "exclude_firebase_uid": exclude_firebase_uid,
        "firebase_uids": firebase_uids,
    }
    if notification_channel:
        payload["notification_channel"] = notification_channel
    _publish_worker_payload(payload)


def publish_notify_user(
    *,
    firebase_uid: str,
    title: str,
    body: str,
    deep_link: str,
    baby_profile_id: uuid.UUID | None,
    notification_channel: str | None = None,
) -> None:
    payload = {
        "type": "notify_user",
        "firebase_uid": firebase_uid,
        "title": title,
        "body": body,
        "deep_link": deep_link,
        "baby_profile_id": str(baby_profile_id) if baby_profile_id else None,
    }
    if notification_channel:
        payload["notification_channel"] = notification_channel
    _publish_worker_payload(payload)
