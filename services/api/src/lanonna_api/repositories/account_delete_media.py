"""Remove authored media on shared babies during account delete."""

from __future__ import annotations

import uuid
from typing import Any

DetachedObject = dict[str, str | None]


def purge_authored_photos_on_shared_babies(
    conn: Any,
    firebase_uid: str,
    sole_owned_baby_ids: list[uuid.UUID],
) -> list[DetachedObject]:
    """Delete photos the user uploaded on babies they do not sole-own.

    Returns storage paths for the worker to delete from GCS (rows are already gone).
    """
    if sole_owned_baby_ids:
        rows = conn.execute(
            """
            SELECT id, display_path, thumb_path
            FROM photos
            WHERE uploader_firebase_uid = %s
              AND NOT (baby_profile_id = ANY(%s::uuid[]))
            """,
            (firebase_uid, sole_owned_baby_ids),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT id, display_path, thumb_path
            FROM photos
            WHERE uploader_firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchall()
    if not rows:
        return []

    photo_ids = [row["id"] for row in rows]
    detached = [
        {
            "display_path": row.get("display_path"),
            "thumb_path": row.get("thumb_path"),
        }
        for row in rows
    ]
    conn.execute(
        """
        UPDATE events SET cover_photo_id = NULL
        WHERE cover_photo_id = ANY(%s::uuid[])
        """,
        (photo_ids,),
    )
    conn.execute(
        "DELETE FROM photo_baby_tags WHERE photo_id = ANY(%s::uuid[])",
        (photo_ids,),
    )
    conn.execute(
        "DELETE FROM photo_comments WHERE photo_id = ANY(%s::uuid[])",
        (photo_ids,),
    )
    conn.execute(
        "DELETE FROM photo_squishes WHERE photo_id = ANY(%s::uuid[])",
        (photo_ids,),
    )
    conn.execute("DELETE FROM photos WHERE id = ANY(%s::uuid[])", (photo_ids,))
    return detached


def collect_and_delete_baby_export_jobs(
    conn: Any,
    baby_profile_id: uuid.UUID,
) -> list[str]:
    """Delete export jobs for one baby profile; return GCS paths to purge."""
    rows = conn.execute(
        """
        SELECT object_path
        FROM baby_data_export_jobs
        WHERE baby_profile_id = %s
          AND object_path IS NOT NULL
        """,
        (baby_profile_id,),
    ).fetchall()
    paths = [row["object_path"] for row in rows if row.get("object_path")]
    conn.execute(
        "DELETE FROM baby_data_export_jobs WHERE baby_profile_id = %s",
        (baby_profile_id,),
    )
    return paths


def collect_and_delete_user_export_jobs(
    conn: Any,
    firebase_uid: str,
) -> list[str]:
    """Delete export job rows for this user; return GCS object paths to purge."""
    rows = conn.execute(
        """
        SELECT object_path
        FROM baby_data_export_jobs
        WHERE requested_by_firebase_uid = %s
          AND object_path IS NOT NULL
        """,
        (firebase_uid,),
    ).fetchall()
    paths = [row["object_path"] for row in rows if row.get("object_path")]
    conn.execute(
        "DELETE FROM baby_data_export_jobs WHERE requested_by_firebase_uid = %s",
        (firebase_uid,),
    )
    return paths
