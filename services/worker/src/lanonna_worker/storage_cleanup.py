from __future__ import annotations

import logging
import uuid
from typing import Any

from lanonna_worker import gcs_delete
from lanonna_worker.config import settings
from lanonna_worker.db import get_connection

logger = logging.getLogger("lanonna.worker.storage_cleanup")

_FAILED_MESSAGE = "Storage cleanup could not be completed."


def _reclaim_stale_running_jobs(conn: Any) -> None:
    conn.execute(
        """
        UPDATE storage_cleanup_jobs
        SET status = 'pending',
            started_at = NULL
        WHERE status = 'running'
          AND started_at IS NOT NULL
          AND started_at < now() - interval '30 minutes'
        """
    )


def _mark_failed(conn: Any, job_id: uuid.UUID) -> None:
    conn.execute(
        """
        UPDATE storage_cleanup_jobs
        SET status = 'failed',
            error_message = %s,
            completed_at = now()
        WHERE id = %s
          AND status = 'running'
        """,
        (_FAILED_MESSAGE, job_id),
    )


def _release_claim(conn: Any, job_id: uuid.UUID) -> None:
    conn.execute(
        """
        UPDATE storage_cleanup_jobs
        SET status = 'pending',
            started_at = NULL
        WHERE id = %s
          AND status = 'running'
        """,
        (job_id,),
    )


def _delete_for_babies(conn: Any, baby_ids: list[uuid.UUID]) -> int:
    if not baby_ids:
        return 0
    rows = conn.execute(
        """
        SELECT display_path, thumb_path
        FROM photos
        WHERE baby_profile_id = ANY(%s::uuid[])
        """,
        (baby_ids,),
    ).fetchall()
    count = 0
    for row in rows:
        count += gcs_delete.delete_photo_paths(
            row.get("display_path"),
            row.get("thumb_path"),
        )
    for baby_id in baby_ids:
        count += gcs_delete.delete_prefix(
            settings.display_bucket,
            f"avatars/babies/{baby_id}/",
        )
        count += gcs_delete.delete_prefix(
            settings.display_bucket,
            f"exports/{baby_id}/",
        )
    return count


def run_storage_cleanup(
    job_id: uuid.UUID,
    *,
    redelivery: bool = False,
    final_attempt: bool = True,
) -> None:
    claimed = False
    deleted_total = 0
    try:
        with get_connection() as conn:
            _reclaim_stale_running_jobs(conn)
            job = conn.execute(
                """
                SELECT id, status, firebase_uid, baby_profile_ids,
                       detached_objects, export_object_paths
                FROM storage_cleanup_jobs
                WHERE id = %s
                """,
                (job_id,),
            ).fetchone()
            if job is None:
                logger.warning("storage_cleanup_job_not_found job_id=%s", job_id)
                return
            if job["status"] == "completed":
                logger.info("storage_cleanup_job_skip_completed job_id=%s", job_id)
                return
            row = conn.execute(
                """
                UPDATE storage_cleanup_jobs
                SET status = 'running',
                    started_at = now()
                WHERE id = %s
                  AND (status = 'pending' OR (status = 'running' AND %s))
                RETURNING firebase_uid, baby_profile_ids,
                          detached_objects, export_object_paths
                """,
                (job_id, redelivery),
            ).fetchone()
            if row is None:
                if job["status"] == "running":
                    logger.info("storage_cleanup_job_already_running job_id=%s", job_id)
                return
            claimed = True
            firebase_uid = row["firebase_uid"]
            baby_ids = list(row["baby_profile_ids"] or [])
            detached = row["detached_objects"] or []
            export_paths = list(row["export_object_paths"] or [])

        for item in detached:
            if isinstance(item, dict):
                deleted_total += gcs_delete.delete_photo_paths(
                    item.get("display_path"),
                    item.get("thumb_path"),
                )
        deleted_total += gcs_delete.delete_display_paths(export_paths)
        deleted_total += gcs_delete.delete_prefix(
            settings.display_bucket,
            f"avatars/users/{firebase_uid}/",
        )

        with get_connection() as conn:
            deleted_total += _delete_for_babies(conn, baby_ids)

        with get_connection() as conn:
            cur = conn.execute(
                """
                UPDATE storage_cleanup_jobs
                SET status = 'completed',
                    objects_deleted_count = %s,
                    completed_at = now()
                WHERE id = %s
                  AND status = 'running'
                """,
                (deleted_total, job_id),
            )
            if getattr(cur, "rowcount", 0) == 0:
                logger.warning("storage_cleanup_complete_lost_claim job_id=%s", job_id)
                return
        logger.info(
            "storage_cleanup_completed job_id=%s objects_deleted=%s",
            job_id,
            deleted_total,
        )
    except gcs_delete.GcsDeleteError:
        logger.exception(
            "storage_cleanup_gcs_failed job_id=%s final_attempt=%s",
            job_id,
            final_attempt,
        )
        if claimed:
            with get_connection() as conn:
                if final_attempt:
                    _mark_failed(conn, job_id)
                else:
                    _release_claim(conn, job_id)
        raise
    except Exception:
        logger.exception(
            "storage_cleanup_failed job_id=%s final_attempt=%s",
            job_id,
            final_attempt,
        )
        if claimed:
            with get_connection() as conn:
                if final_attempt:
                    _mark_failed(conn, job_id)
                else:
                    _release_claim(conn, job_id)
        raise
