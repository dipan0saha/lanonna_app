from __future__ import annotations

import io
import logging
import re
from typing import Any

from google.cloud import storage
from PIL import Image

from lanonna_worker.config import settings
from lanonna_worker.db import mark_photo_ready

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
        updated = mark_photo_ready(
            display_path=name,
            thumb_path=thumb_path,
            object_generation=gen_int,
            byte_length=len(data),
        )
        if updated:
            logger.info(
                "photo_ready photo_id=%s thumb=%s bytes=%s",
                photo_id,
                thumb_path,
                len(data),
            )
        else:
            logger.info("photo_ready skipped (idempotent) name=%s", name)
    except RuntimeError:
        logger.warning("DB not configured; thumb uploaded without SQL update path=%s", name)
