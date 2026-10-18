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
    DatabaseNotConfiguredError,
    get_ready_photo_by_display_path,
    mark_photo_ready,
)
from lanonna_activity_copy import NotificationKind
from lanonna_worker.notifications import process_notify_fan_out

logger = logging.getLogger("lanonna.worker")

_DISPLAY_PATH = re.compile(r"^display/([0-9a-f-]{36})\.(jpg|jpeg|webp)$", re.I)
_THUMB_WIDTH = 320
# Match API photo init max (services/api routers/photos.py).
MAX_DISPLAY_BYTES = 2_097_152
MAX_IMAGE_PIXELS = 20_000_000


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
    blob_size = display_blob.size
    if blob_size is not None and blob_size > MAX_DISPLAY_BYTES:
        logger.warning(
            "display_object_too_large name=%s bytes=%s max=%s",
            name,
            blob_size,
            MAX_DISPLAY_BYTES,
        )
        return

    data = display_blob.download_as_bytes()
    if len(data) > MAX_DISPLAY_BYTES:
        logger.warning(
            "display_download_too_large name=%s bytes=%s max=%s",
            name,
            len(data),
            MAX_DISPLAY_BYTES,
        )
        return

    try:
        with Image.open(io.BytesIO(data)) as opened:
            opened.load()
            image = opened.convert("RGB")
    except Image.DecompressionBombError:
        logger.warning("display_image_decompression_bomb name=%s", name)
        return
    w, h = image.size
    if w * h > MAX_IMAGE_PIXELS:
        logger.warning(
            "display_image_too_many_pixels name=%s pixels=%s max=%s",
            name,
            w * h,
            MAX_IMAGE_PIXELS,
        )
        return
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
    except DatabaseNotConfiguredError:
        logger.warning("DB not configured; thumb uploaded without SQL update path=%s", name)


def _maybe_notify_photo_ready(
    ready_row: dict[str, Any],
    *,
    object_generation: int | None,
) -> None:
    if ready_row.get("purpose") == "event_cover":
        return
    photo_uuid = ready_row["id"]
    if isinstance(photo_uuid, str):
        photo_uuid = uuid.UUID(photo_uuid)
    gen = object_generation
    if gen is None:
        gen = ready_row.get("display_object_generation")

    # Idempotency lives in the fan-out itself: it claims ``dedupe_key`` in the same
    # transaction as the inbox inserts, so a failed fan-out rolls the claim back and the
    # Pub/Sub retry re-notifies (a separate pre-claim would be committed first and lose it).
    dedupe_key = f"photo_ready:{photo_uuid}:{gen if gen is not None else 0}"
    process_notify_fan_out(
        {
            "type": "notify_fan_out",
            "dedupe_key": dedupe_key,
            "baby_profile_id": str(ready_row["baby_profile_id"]),
            "kind": NotificationKind.PHOTO_SHARED.value,
            "params": {},
            "actor_firebase_uid": ready_row["uploader_firebase_uid"],
            "deep_link": f"/gallery/photo/{ready_row['id']}",
            "recipient_mode": "baby_members",
            "exclude_firebase_uid": ready_row["uploader_firebase_uid"],
            "firebase_uids": [],
            "notification_channel": "gallery",
        }
    )
