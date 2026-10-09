from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def list_tagged_babies_for_photo(
    photo_id: uuid.UUID,
    viewer_firebase_uid: str,
) -> list[dict[str, Any]]:
    """Tagged babies on a photo that the viewer is a member of (FR-GAL-008 read scope)."""
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT b.id, b.name
            FROM photo_baby_tags t
            JOIN baby_profiles b ON b.id = t.tagged_baby_profile_id
            JOIN baby_memberships m
              ON m.baby_profile_id = t.tagged_baby_profile_id
             AND m.firebase_uid = %s
            WHERE t.photo_id = %s
            ORDER BY b.name ASC
            """,
            (viewer_firebase_uid, photo_id),
        ).fetchall()
    return [dict(r) for r in rows]


def replace_photo_baby_tags(
    photo_id: uuid.UUID,
    tagged_baby_profile_ids: list[uuid.UUID],
) -> None:
    with get_connection() as conn:
        conn.execute(
            "DELETE FROM photo_baby_tags WHERE photo_id = %s",
            (photo_id,),
        )
        for baby_id in tagged_baby_profile_ids:
            conn.execute(
                """
                INSERT INTO photo_baby_tags (photo_id, tagged_baby_profile_id)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
                """,
                (photo_id, baby_id),
            )
