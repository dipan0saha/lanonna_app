from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def create_pending_photo(
    baby_profile_id: uuid.UUID,
    uploader_firebase_uid: str,
    content_type: str,
    byte_length: int,
    caption: str | None = None,
) -> dict[str, Any]:
    photo_id = uuid.uuid4()
    ext = "webp" if content_type == "image/webp" else "jpg"
    display_path = f"display/{photo_id}.{ext}"
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid,
                status, display_path, content_type, byte_length, caption
            )
            VALUES (%s, %s, %s, 'pending', %s, %s, %s, %s)
            RETURNING id, baby_profile_id, status, display_path, content_type, byte_length, caption, created_at
            """,
            (
                photo_id,
                baby_profile_id,
                uploader_firebase_uid,
                display_path,
                content_type,
                byte_length,
                caption,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("create_pending_photo returned no row")
    return dict(row)
