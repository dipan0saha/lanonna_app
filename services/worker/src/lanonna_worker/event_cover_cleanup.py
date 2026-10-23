"""Daily purge of event covers that were uploaded and never attached (#414).

A cover is uploaded before its event is saved; if the owner abandons the form,
the ``photos`` row and its GCS objects stay forever. Cloud Scheduler sends
``purge_stale_event_covers`` once a day (``scripts/setup-schedulers.sh``).

Each cover is removed in its own transaction:

1. Lock the photo row (``FOR UPDATE SKIP LOCKED``). Attaching a cover writes a
   foreign key to it, which takes a key-share lock on that row, so a cover being
   attached right now is skipped, and nothing can attach it while we hold the lock.
2. Re-check that no event or birth announcement points at it, in a new
   statement, so a reference committed after the candidate list was read counts.
3. Delete the GCS objects, then the row, and commit. If GCS fails the row is
   kept (rolled back) and the next run retries; an object that is already gone
   counts as deleted.
"""

from __future__ import annotations

import logging
import uuid

from lanonna_worker.db import PhotoPurpose, get_connection
from lanonna_worker.gcs_delete import delete_photo_paths

logger = logging.getLogger("lanonna.worker.event_cover_cleanup")

# Long enough that a cover picked in an open event form is never "abandoned".
DEFAULT_STALE_EVENT_COVER_HOURS = 24
# Bounds one run; the rest are picked up the next day.
MAX_COVERS_PER_RUN = 500

_UNREFERENCED = """
    NOT EXISTS (SELECT 1 FROM events e WHERE e.cover_photo_id = p.id)
    AND NOT EXISTS (SELECT 1 FROM birth_announcements a WHERE a.photo_id = p.id)
"""


class EventCoverPurgeIncomplete(RuntimeError):
    """Some covers could not be removed; the scheduler retries the job."""


def _stale_cover_ids(older_than_hours: int, limit: int) -> list[uuid.UUID]:
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT p.id
            FROM photos p
            WHERE p.purpose = %s
              AND p.created_at < now() - make_interval(hours => %s)
              AND {_UNREFERENCED}
            ORDER BY p.created_at, p.id
            LIMIT %s
            """,
            (PhotoPurpose.EVENT_COVER.value, older_than_hours, limit),
        ).fetchall()
    return [row["id"] for row in rows]


def _purge_one(photo_id: uuid.UUID) -> bool:
    """Remove one unattached cover. False when it is in use or locked."""
    with get_connection() as conn:
        locked = conn.execute(
            """
            SELECT p.display_path, p.thumb_path
            FROM photos p
            WHERE p.id = %s AND p.purpose = %s
            FOR UPDATE SKIP LOCKED
            """,
            (photo_id, PhotoPurpose.EVENT_COVER.value),
        ).fetchone()
        if locked is None:
            return False
        still_free = conn.execute(
            f"SELECT 1 FROM photos p WHERE p.id = %s AND {_UNREFERENCED}",
            (photo_id,),
        ).fetchone()
        if still_free is None:
            return False
        # Storage first: a GCS failure raises, rolls back, and keeps the row.
        delete_photo_paths(locked["display_path"], locked["thumb_path"])
        conn.execute("DELETE FROM photos WHERE id = %s", (photo_id,))
    return True


def purge_stale_unreferenced_event_covers(
    older_than_hours: int = DEFAULT_STALE_EVENT_COVER_HOURS,
    *,
    limit: int = MAX_COVERS_PER_RUN,
) -> int:
    """Remove event covers older than [older_than_hours] that nothing uses.

    Returns how many were removed. Raises ``EventCoverPurgeIncomplete`` after
    trying every candidate if any failed, so the push is retried.
    """
    removed = 0
    failed = 0
    for photo_id in _stale_cover_ids(older_than_hours, limit):
        try:
            if _purge_one(photo_id):
                removed += 1
        except Exception:
            failed += 1
            logger.exception("purge_stale_event_cover_failed photo_id=%s", photo_id)
    logger.info(
        "purge_stale_unreferenced_event_covers removed=%s failed=%s older_than_hours=%s",
        removed,
        failed,
        older_than_hours,
    )
    if failed:
        raise EventCoverPurgeIncomplete(f"{failed} event cover(s) not removed")
    return removed
