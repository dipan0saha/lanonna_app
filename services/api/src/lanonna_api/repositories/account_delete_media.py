"""SQL slice of media and export removal for account and baby profile delete.

Photo and export paths are collected in the caller's transaction, then baby rows
are hard-deleted (``ON DELETE CASCADE``). Paths go into ``storage_cleanup_jobs``
so the worker can purge GCS without reading ``photos``.
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from typing import Any

DetachedObject = dict[str, str | None]


def purge_authored_photos_on_shared_babies(
    conn: Any,
    firebase_uid: str,
    sole_owned_baby_ids: Sequence[uuid.UUID],
) -> list[DetachedObject]:
    """Delete photos (gallery and event covers) the user uploaded on babies they do
    not sole-own; return their display/thumbnail paths.

    Comments, squishes, tags and worker idempotency rows cascade; events and birth
    announcements using a deleted photo lose it via ``ON DELETE SET NULL``. Photos
    on sole-owned babies are collected and removed when those profiles are
    hard-deleted.
    """
    rows = conn.execute(
        """
        DELETE FROM photos
        WHERE uploader_firebase_uid = %s
          AND NOT (baby_profile_id = ANY(%s::uuid[]))
        RETURNING display_path, thumb_path
        """,
        (firebase_uid, list(sole_owned_baby_ids)),
    ).fetchall()
    return [
        {"display_path": row["display_path"], "thumb_path": row["thumb_path"]}
        for row in rows
    ]


def collect_and_delete_export_jobs(
    conn: Any,
    *,
    firebase_uid: str | None = None,
    baby_profile_ids: Sequence[uuid.UUID] = (),
) -> list[str]:
    """Delete export jobs requested by ``firebase_uid`` or for any of
    ``baby_profile_ids``; return the export object paths to purge."""
    rows = conn.execute(
        """
        DELETE FROM baby_data_export_jobs
        WHERE requested_by_firebase_uid = %s
           OR baby_profile_id = ANY(%s::uuid[])
        RETURNING object_path
        """,
        (firebase_uid, list(baby_profile_ids)),
    ).fetchall()
    return [row["object_path"] for row in rows if row["object_path"]]


def collect_photo_storage_for_babies(
    conn: Any,
    baby_profile_ids: Sequence[uuid.UUID],
) -> list[DetachedObject]:
    """Return display/thumbnail paths for every photo on the given babies (pre-delete)."""
    if not baby_profile_ids:
        return []
    rows = conn.execute(
        """
        SELECT display_path, thumb_path
        FROM photos
        WHERE baby_profile_id = ANY(%s::uuid[])
        """,
        (list(baby_profile_ids),),
    ).fetchall()
    return [
        {"display_path": row["display_path"], "thumb_path": row["thumb_path"]}
        for row in rows
    ]


def hard_delete_baby_profiles(
    conn: Any,
    baby_profile_ids: Sequence[uuid.UUID],
) -> None:
    """Remove baby profiles and all dependent rows (DB CASCADE)."""
    if not baby_profile_ids:
        return
    conn.execute(
        """
        DELETE FROM baby_profiles
        WHERE id = ANY(%s::uuid[])
        """,
        (list(baby_profile_ids),),
    )
