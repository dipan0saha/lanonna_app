from __future__ import annotations

import io
import logging
import re
import uuid
from typing import Any

from google.cloud import storage
from PIL import Image

from lanonna_worker.config import settings
from lanonna_worker.db import (
    get_connection,
    get_ready_photo_by_display_path,
    mark_photo_ready,
)
from lanonna_worker.idempotency import try_claim_photo_ready_notify
from lanonna_worker.notifications import process_notify_fan_out

logger = logging.getLogger("lanonna.worker")

_DISPLAY_PATH = re.compile(r"^display/([0-9a-f-]{36})\.(jpg|jpeg|webp)$", re.I)
_THUMB_WIDTH = 320


def process_gcs_finalize(payload: dict[str, Any]) -> None:
    bucket = payload.get("bucket")
    name = payload.get("name")
    generation = payload.get("generation")
    if not bucket or not name:
        return
    if bucket != settings.display_bucket:
        logger.debug("Ignoring bucket %s", bucket)
        return
    match = _DISPLAY_PATH.match(name)
    if not match:
        logger.info("Skipping non-photo display object name=%s", name)
        return

    photo_id = match.group(1)
    thumb_path = f"thumbnails/{photo_id}.jpg"

    client = storage.Client(project=settings.gcp_project_id)
    display_blob = client.bucket(bucket).blob(name)
    if not display_blob.exists():
        logger.warning("Display object missing name=%s", name)
        return

    display_blob.reload()
    data = display_blob.download_as_bytes()
    image = Image.open(io.BytesIO(data))
    image = image.convert("RGB")
    w, h = image.size
    if w > _THUMB_WIDTH:
        new_h = int(h * (_THUMB_WIDTH / w))
        image = image.resize((_THUMB_WIDTH, new_h), Image.Resampling.LANCZOS)

    out = io.BytesIO()
    image.save(out, format="JPEG", quality=82, optimize=True)
    thumb_bytes = out.getvalue()

    thumb_blob = client.bucket(settings.thumbnails_bucket).blob(thumb_path)
    thumb_blob.upload_from_string(thumb_bytes, content_type="image/jpeg")

    gen_int = int(generation) if generation is not None else None
    try:
        ready_row = mark_photo_ready(
            display_path=name,
            thumb_path=thumb_path,
            object_generation=gen_int,
            byte_length=len(data),
        )
        if ready_row is None:
            ready_row = get_ready_photo_by_display_path(name)
            if ready_row:
                logger.info("photo_ready idempotent name=%s", name)
        else:
            logger.info(
                "photo_ready photo_id=%s thumb=%s bytes=%s",
                photo_id,
                thumb_path,
                len(data),
            )

        if ready_row:
            _maybe_notify_photo_ready(ready_row, object_generation=gen_int)
    except RuntimeError:
        logger.warning("DB not configured; thumb uploaded without SQL update path=%s", name)


def _maybe_notify_photo_ready(
    ready_row: dict[str, Any],
    *,
    object_generation: int | None,
) -> None:
    photo_uuid = ready_row["id"]
    if isinstance(photo_uuid, str):
        photo_uuid = uuid.UUID(photo_uuid)
    gen = object_generation
    if gen is None:
        gen = ready_row.get("display_object_generation")

    with get_connection() as conn:
        if not try_claim_photo_ready_notify(conn, photo_uuid, gen):
            logger.info(
                "photo_ready_notify_skip_duplicate photo_id=%s generation=%s",
                photo_uuid,
                gen,
            )
            return

    dedupe_key = f"photo_ready:{photo_uuid}:{gen if gen is not None else 0}"
    process_notify_fan_out(
        {
            "type": "notify_fan_out",
            "dedupe_key": dedupe_key,
            "baby_profile_id": str(ready_row["baby_profile_id"]),
            "title": "New photo",
            "body": "A new photo was shared",
            "deep_link": f"/gallery/photo/{ready_row['id']}",
            "recipient_mode": "baby_members",
            "exclude_firebase_uid": ready_row["uploader_firebase_uid"],
            "firebase_uids": [],
            "notification_channel": "gallery",
        }
    )
