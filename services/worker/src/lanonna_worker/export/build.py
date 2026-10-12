"""Collect, shape, and serialize one baby export."""

from __future__ import annotations

import json
import logging
import uuid
from typing import Any

from lanonna_worker.config import settings
from lanonna_worker.export.collect import ACTIVITY_EXPORT_MAX_ROWS, collect_baby_export
from lanonna_worker.export.document import build_export_document
from lanonna_worker.export.media import sign_export_read_url

logger = logging.getLogger("lanonna.worker.export")


def build_baby_export_json(
    conn: Any,
    *,
    baby_id: uuid.UUID,
    requester_uid: str,
    sign_read: Any = None,
) -> bytes:
    collected = collect_baby_export(conn, baby_id, requester_uid)
    if collected["activity_total"] > ACTIVITY_EXPORT_MAX_ROWS:
        logger.warning(
            "export_activity_truncated baby_id=%s total=%s max=%s",
            baby_id,
            collected["activity_total"],
            ACTIVITY_EXPORT_MAX_ROWS,
        )
    signer = sign_read or sign_export_read_url
    document = build_export_document(
        collected,
        baby_id=baby_id,
        sign_read=signer,
        display_bucket=settings.display_bucket,
        thumbnails_bucket=settings.thumbnails_bucket,
    )
    return json.dumps(document, indent=2).encode("utf-8")
