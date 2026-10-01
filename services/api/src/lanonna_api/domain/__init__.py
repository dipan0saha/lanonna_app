from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def assert_owner_membership(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE baby_profile_id = %s
              AND firebase_uid = %s
              AND role = 'owner'
              AND removed_at IS NULL
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    if row is None:
        raise PermissionError("Owner membership required for this baby profile.")


def create_pending_photo(
    baby_profile_id: uuid.UUID,
    uploader_firebase_uid: str,
    content_type: str,
    byte_length: int,
) -> dict[str, Any]:
    photo_id = uuid.uuid4()
    ext = "webp" if content_type == "image/webp" else "jpg"
    display_path = f"display/{photo_id}.{ext}"
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid,
                status, display_path, content_type, byte_length
            )
            VALUES (%s, %s, %s, 'pending', %s, %s, %s)
            RETURNING id, baby_profile_id, status, display_path, content_type, byte_length, created_at
            """,
            (
                photo_id,
                baby_profile_id,
                uploader_firebase_uid,
                display_path,
                content_type,
                byte_length,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("create_pending_photo returned no row")
    return dict(row)
