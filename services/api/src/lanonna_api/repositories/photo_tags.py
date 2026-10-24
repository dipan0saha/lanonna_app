from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.repositories.child_write_locks import (
    ChildWriteParent,
    ensure_parent_row_for_child_write,
)


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
             AND m.removed_at IS NULL
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
        # Babies (photo's + tagged, ascending id) then the photo, before the
        # DELETE below touches rows a baby delete would cascade into (#442).
        ensure_parent_row_for_child_write(
            ChildWriteParent.PHOTOS,
            photo_id,
            conn,
            also_baby_ids=tagged_baby_profile_ids,
        )
        conn.execute(
            "DELETE FROM photo_baby_tags WHERE photo_id = %s",
            (photo_id,),
        )
        if tagged_baby_profile_ids:
            conn.execute(
                """
                INSERT INTO photo_baby_tags (photo_id, tagged_baby_profile_id)
                SELECT %s, tagged
                FROM unnest(%s::uuid[]) AS tagged
                ON CONFLICT DO NOTHING
                """,
                (photo_id, list(tagged_baby_profile_ids)),
            )
