from __future__ import annotations

import logging
import uuid
from typing import Any

from lanonna_api.config import settings

logger = logging.getLogger(__name__)

EXPORT_QUEUE_FAILED_MESSAGE = (
    "Export could not be started. Please try again in a few minutes."
)
from lanonna_api.pubsub import publish_baby_data_export
from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.repositories.data_export import (
    get_latest_export_job_for_baby,
    insert_export_job,
    mark_export_job_failed,
)
from lanonna_api.storage import mint_signed_read_url


def _job_response(row: dict[str, Any]) -> dict[str, Any]:
    download_url = None
    if row.get("status") == "ready" and row.get("object_path"):
        download_url = mint_signed_read_url(
            settings.display_bucket,
            row["object_path"],
        )
    return {
        "id": str(row["id"]),
        "baby_profile_id": str(row["baby_profile_id"]),
        "status": row["status"],
        "object_path": row.get("object_path"),
        "error_message": row.get("error_message"),
        "download_url": download_url,
        "created_at": row["created_at"].isoformat()
        if hasattr(row["created_at"], "isoformat")
        else str(row["created_at"]),
        "completed_at": row["completed_at"].isoformat()
        if row.get("completed_at") and hasattr(row["completed_at"], "isoformat")
        else (str(row["completed_at"]) if row.get("completed_at") else None),
    }


def request_baby_data_export(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    if get_baby_for_owner(firebase_uid, baby_profile_id) is None:
        raise PermissionError("Owner access required for this baby profile.")
    row = insert_export_job(baby_profile_id, firebase_uid)
    try:
        publish_baby_data_export(row["id"])
    except Exception as exc:
        logger.exception(
            "export_queue_failed job_id=%s baby_profile_id=%s",
            row["id"],
            baby_profile_id,
        )
        mark_export_job_failed(row["id"], EXPORT_QUEUE_FAILED_MESSAGE)
        raise RuntimeError(EXPORT_QUEUE_FAILED_MESSAGE) from exc
    return _job_response(row)


def latest_baby_data_export(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any] | None:
    if get_baby_for_owner(firebase_uid, baby_profile_id) is None:
        raise PermissionError("Owner access required for this baby profile.")
    row = get_latest_export_job_for_baby(baby_profile_id, firebase_uid)
    if row is None:
        return None
    return _job_response(row)
