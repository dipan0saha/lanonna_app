from __future__ import annotations

import logging

from lanonna_worker.db import PhotoPurpose, get_connection
from lanonna_worker.gcs_delete import delete_photo_paths

logger = logging.getLogger("lanonna.worker.event_cover_cleanup")

DEFAULT_STALE_EVENT_COVER_HOURS = 24


def purge_stale_unreferenced_event_covers(
    older_than_hours: int = DEFAULT_STALE_EVENT_COVER_HOURS,
) -> int:
    """Remove event_cover rows never linked to an event (upload abandoned)."""
    with get_connection() as conn:
        rows = conn.execute(
            """
            DELETE FROM photos p
            WHERE p.purpose = %s
              AND p.created_at < now() - make_interval(hours => %s)
              AND NOT EXISTS (SELECT 1 FROM events e WHERE e.cover_photo_id = p.id)
              AND NOT EXISTS (
                  SELECT 1 FROM birth_announcements a WHERE a.photo_id = p.id
              )
            RETURNING display_path, thumb_path
            """,
            (PhotoPurpose.EVENT_COVER.value, older_than_hours),
        ).fetchall()
    for row in rows:
        delete_photo_paths(row.get("display_path"), row.get("thumb_path"))
    count = len(rows)
    logger.info(
        "purge_stale_unreferenced_event_covers removed=%s older_than_hours=%s",
        count,
        older_than_hours,
    )
    return count
