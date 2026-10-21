"""SQL slice of media and export removal for account and baby profile delete.

Rows are deleted here, in the caller's transaction; the returned storage paths go
into a ``storage_cleanup_jobs`` row so the worker deletes the GCS objects.
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
    on sole-owned babies stay with the soft-deleted baby; the worker purges their
    objects by baby id.
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
