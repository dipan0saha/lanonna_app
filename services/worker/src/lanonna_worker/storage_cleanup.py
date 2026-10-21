"""Async GCS purge after account or baby profile deletion (``storage_cleanup_jobs``).

The API commits the job with the SQL delete and publishes ``storage_cleanup`` after
commit. Cloud Scheduler's ``sweep_storage_cleanup_jobs`` re-runs jobs whose publish
was lost, whose worker died mid-run, or that used up their Pub/Sub retries. Deletes
treat an absent object as done, so running a job twice is safe.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from lanonna_worker import gcs_delete
from lanonna_worker.config import settings
from lanonna_worker.db import get_connection

logger = logging.getLogger("lanonna.worker.storage_cleanup")

_FAILED_MESSAGE = "Storage cleanup could not be completed."
_SWEEP_BATCH = 10


def _claim(conn: Any, job_id: uuid.UUID, *, redelivery: bool) -> dict[str, Any] | None:
    """``pending`` → ``running``. A Pub/Sub redelivery may also take over a
    ``running`` job whose worker died. None if missing, completed, or failed."""
    return conn.execute(
        """
        UPDATE storage_cleanup_jobs
        SET status = 'running',
            started_at = now()
        WHERE id = %s
          AND (status = 'pending' OR (status = 'running' AND %s))
        RETURNING kind, firebase_uid, baby_profile_ids,
                  detached_objects, export_object_paths
        """,
        (job_id, redelivery),
    ).fetchone()


def _finish(conn: Any, job_id: uuid.UUID, *, failed: bool, deleted: int = 0) -> None:
    if failed:
        conn.execute(
            """
            UPDATE storage_cleanup_jobs
            SET status = 'failed', error_message = %s, completed_at = now()
            WHERE id = %s AND status = 'running'
            """,
            (_FAILED_MESSAGE, job_id),
        )
    else:
        conn.execute(
            """
            UPDATE storage_cleanup_jobs
            SET status = 'completed', objects_deleted_count = %s,
                error_message = NULL, completed_at = now()
            WHERE id = %s AND status = 'running'
            """,
            (deleted, job_id),
        )


def _release_claim(conn: Any, job_id: uuid.UUID) -> None:
    """Back to ``pending`` so the next Pub/Sub delivery can claim it."""
    conn.execute(
        """
        UPDATE storage_cleanup_jobs
        SET status = 'pending', started_at = NULL
        WHERE id = %s AND status = 'running'
        """,
        (job_id,),
    )


def _baby_photo_paths(baby_ids: list[uuid.UUID]) -> list[dict[str, Any]]:
    """Every photo on the deleted babies (gallery and event covers, any uploader)."""
    if not baby_ids:
        return []
    with get_connection() as conn:
        return conn.execute(
            """
            SELECT display_path, thumb_path
            FROM photos
            WHERE baby_profile_id = ANY(%s::uuid[])
            """,
            (baby_ids,),
        ).fetchall()


def _purge(job: dict[str, Any]) -> int:
    baby_ids = [uuid.UUID(str(b)) for b in job["baby_profile_ids"] or []]
    photos = [o for o in job["detached_objects"] or [] if isinstance(o, dict)]
    photos += _baby_photo_paths(baby_ids)

    deleted = sum(
        gcs_delete.delete_photo_paths(p.get("display_path"), p.get("thumb_path"))
        for p in photos
    )
    deleted += gcs_delete.delete_display_paths(job["export_object_paths"] or [])
    prefixes = [
        p for baby_id in baby_ids for p in (f"avatars/babies/{baby_id}/", f"exports/{baby_id}/")
    ]
    if job["kind"] == "account_delete":
        prefixes.append(f"avatars/users/{job['firebase_uid']}/")
    for prefix in prefixes:
        deleted += gcs_delete.delete_prefix(settings.display_bucket, prefix)
    return deleted


def run_storage_cleanup(
    job_id: uuid.UUID,
    *,
    redelivery: bool = False,
    final_attempt: bool = True,
) -> None:
    """Run one job. Raises on failure: the job is released for the next delivery,
    or marked ``failed`` on the final attempt (the sweep retries it later)."""
    with get_connection() as conn:
        job = _claim(conn, job_id, redelivery=redelivery)
    if job is None:
        logger.info("storage_cleanup_job_skipped job_id=%s", job_id)
        return
    try:
        deleted = _purge(job)
    except Exception:
        logger.exception(
            "storage_cleanup_failed job_id=%s final_attempt=%s", job_id, final_attempt
        )
        with get_connection() as conn:
            if final_attempt:
                _finish(conn, job_id, failed=True)
            else:
                _release_claim(conn, job_id)
        raise
    with get_connection() as conn:
        _finish(conn, job_id, failed=False, deleted=deleted)
    logger.info(
        "storage_cleanup_completed job_id=%s kind=%s objects_deleted=%s",
        job_id,
        job["kind"],
        deleted,
    )


def sweep_storage_cleanup_jobs(limit: int = _SWEEP_BATCH) -> int:
    """Cloud Scheduler: re-run stuck jobs (publish lost, worker died, retries used
    up). Returns how many jobs were picked up."""
    with get_connection() as conn:
        rows = conn.execute(
            """
            UPDATE storage_cleanup_jobs
            SET status = 'pending', started_at = NULL
            WHERE id IN (
                SELECT id FROM storage_cleanup_jobs
                WHERE (status = 'pending' AND created_at < now() - interval '10 minutes')
                   OR (status = 'running' AND started_at < now() - interval '30 minutes')
                   OR (status = 'failed' AND completed_at < now() - interval '6 hours')
                ORDER BY created_at
                LIMIT %s
                FOR UPDATE SKIP LOCKED
            )
            RETURNING id
            """,
            (limit,),
        ).fetchall()
    completed = 0
    for row in rows:
        try:
            run_storage_cleanup(row["id"])
            completed += 1
        except Exception:
            continue  # logged and marked failed; a later sweep retries it
    logger.info("storage_cleanup_sweep picked=%s completed=%s", len(rows), completed)
    return len(rows)
