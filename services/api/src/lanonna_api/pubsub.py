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

    topic_path = _publisher_client().topic_path(
        settings.gcp_project_id,
        settings.pubsub_topic_upload,
    )
    data = json.dumps(payload).encode("utf-8")
    future = _publisher_client().publish(topic_path, data)
    future.result(timeout=30)
