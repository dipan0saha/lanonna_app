from __future__ import annotations

import json
import logging
import uuid
from datetime import date, datetime
from typing import Any

from google.cloud import storage

from lanonna_worker.config import settings
from lanonna_worker.db import get_connection

logger = logging.getLogger("lanonna.worker.export")

_EXPORT_FAILED_MESSAGE = "Export could not be completed. Please try again."
ACTIVITY_EXPORT_MAX_ROWS = 500

_BABY_PROFILE_EXPORT_COLUMNS = """
    id, name, expected_birth_date, actual_birth_date, gender, lifecycle_status,
    avatar_url, created_at, updated_at, created_by_firebase_uid,
    registry_shipping_line1, registry_shipping_line2, registry_shipping_city,
    registry_shipping_region, registry_shipping_postal_code, registry_shipping_country_code
"""

_EVENT_EXPORT_COLUMNS = """
    id, baby_profile_id, created_by_firebase_uid, title, starts_at, ends_at,
    description, location, video_call_url, cover_photo_id, catalog_suggestion_id,
    created_at, updated_at
"""

_REGISTRY_EXPORT_COLUMNS = """
    id, baby_profile_id, created_by_firebase_uid, name, priority, description,
    product_url, catalog_suggestion_id, created_at, updated_at
"""

_NAME_SUGGESTION_EXPORT_COLUMNS = """
    id, baby_profile_id, suggested_by_firebase_uid, suggested_name, gender, created_at
"""

_ACTIVITY_EXPORT_COLUMNS = """
    id, baby_profile_id, actor_firebase_uid, event_type, summary, payload, created_at
"""


def _json_default(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    return str(value)


def _reclaim_stale_running_jobs(conn: Any) -> None:
    conn.execute(
        """
        UPDATE baby_data_export_jobs
        SET status = 'pending',
            started_at = NULL
        WHERE status = 'running'
          AND started_at IS NOT NULL
          AND started_at < now() - interval '30 minutes'
        """
    )


def _mark_export_failed(conn: Any, job_id: uuid.UUID) -> None:
    conn.execute(
        """
        UPDATE baby_data_export_jobs
        SET status = 'failed',
            error_message = %s,
            completed_at = now()
        WHERE id = %s
          AND status = 'running'
        """,
        (_EXPORT_FAILED_MESSAGE, job_id),
    )


def _touch_export_running(conn: Any, job_id: uuid.UUID) -> None:
    """Refresh ``started_at`` so stale reclaim does not interrupt an active export."""
    conn.execute(
        """
        UPDATE baby_data_export_jobs
        SET started_at = now()
        WHERE id = %s
          AND status = 'running'
        """,
        (job_id,),
    )


def _delete_export_blob(blob: Any, object_path: str) -> None:
    try:
        blob.delete()
        logger.info("export_orphan_deleted path=%s", object_path)
    except Exception:
        logger.exception("export_orphan_delete_failed path=%s", object_path)


def _release_export_claim(conn: Any, job_id: uuid.UUID) -> None:
    """Return a claimed job to ``pending`` so the next Pub/Sub delivery can run it."""
    conn.execute(
        """
        UPDATE baby_data_export_jobs
        SET status = 'pending',
            started_at = NULL
        WHERE id = %s
          AND status = 'running'
        """,
        (job_id,),
    )


def run_baby_data_export(
    job_id: uuid.UUID,
    *,
    redelivery: bool = False,
    final_attempt: bool = True,
) -> None:
    """Build and upload a baby data export for ``job_id``.

    The job row is the idempotency guard (``pending`` -> ``running`` -> ``ready``/``failed``).

    ``redelivery``: Pub/Sub is redelivering after an earlier attempt that did not ack. A job
    still ``running`` then belongs to a crashed or timed-out attempt, so it is taken over
    (the export is idempotent: it overwrites the same object path).

    ``final_attempt``: only the last delivery attempt marks the job ``failed`` (user-visible).
    Earlier failures release the claim back to ``pending`` and re-raise so Pub/Sub retries.
    """
    baby_id: uuid.UUID | None = None
    claimed = False
    blob: Any = None
    object_path: str | None = None
    uploaded = False
    try:
        with get_connection() as conn:
            _reclaim_stale_running_jobs(conn)
            job = conn.execute(
                """
                SELECT id, baby_profile_id, status
                FROM baby_data_export_jobs
                WHERE id = %s
                """,
                (job_id,),
            ).fetchone()
            if job is None:
                logger.warning("export_job_not_found job_id=%s", job_id)
                return
            if job["status"] in ("ready", "failed"):
                logger.info(
                    "export_job_skip_status job_id=%s status=%s",
                    job_id,
                    job["status"],
                )
                return
            row = conn.execute(
                """
                UPDATE baby_data_export_jobs
                SET status = 'running',
                    started_at = now()
                WHERE id = %s
                  AND (status = 'pending' OR (status = 'running' AND %s))
                RETURNING baby_profile_id
                """,
                (job_id, redelivery),
            ).fetchone()
            if row is None:
                if job["status"] == "running":
                    logger.info("export_job_already_running job_id=%s", job_id)
                return
            baby_id = row["baby_profile_id"]
            claimed = True
            _touch_export_running(conn, job_id)

            baby = conn.execute(
                f"SELECT {_BABY_PROFILE_EXPORT_COLUMNS} FROM baby_profiles WHERE id = %s",
                (baby_id,),
            ).fetchone()
            photos = conn.execute(
                """
                SELECT id, caption, status, display_path, thumb_path, created_at
                FROM photos WHERE baby_profile_id = %s
                ORDER BY created_at
                """,
                (baby_id,),
            ).fetchall()
            events = conn.execute(
                f"""
                SELECT {_EVENT_EXPORT_COLUMNS}
                FROM events WHERE baby_profile_id = %s ORDER BY starts_at
                """,
                (baby_id,),
            ).fetchall()
            registry = conn.execute(
                f"""
                SELECT {_REGISTRY_EXPORT_COLUMNS}
                FROM registry_items WHERE baby_profile_id = %s ORDER BY created_at
                """,
                (baby_id,),
            ).fetchall()
            names = conn.execute(
                f"""
                SELECT {_NAME_SUGGESTION_EXPORT_COLUMNS}
                FROM name_suggestions WHERE baby_profile_id = %s ORDER BY created_at
                """,
                (baby_id,),
            ).fetchall()
            activity_count_row = conn.execute(
                """
                SELECT COUNT(*)::int AS n
                FROM activity_events
                WHERE baby_profile_id = %s
                """,
                (baby_id,),
            ).fetchone()
            activity_total = int(activity_count_row["n"]) if activity_count_row else 0
            if activity_total > ACTIVITY_EXPORT_MAX_ROWS:
                logger.warning(
                    "export_activity_truncated baby_id=%s total=%s max=%s",
                    baby_id,
                    activity_total,
                    ACTIVITY_EXPORT_MAX_ROWS,
                )
            activity = conn.execute(
                f"""
                SELECT {_ACTIVITY_EXPORT_COLUMNS}
                FROM activity_events
                WHERE baby_profile_id = %s
                ORDER BY created_at DESC
                LIMIT %s
                """,
                (baby_id, ACTIVITY_EXPORT_MAX_ROWS),
            ).fetchall()
            _touch_export_running(conn, job_id)

        payload = {
            "baby_profile": dict(baby) if baby else None,
            "photos": [dict(p) for p in photos],
            "events": [dict(e) for e in events],
            "registry_items": [dict(r) for r in registry],
            "name_suggestions": [dict(n) for n in names],
            "activity_events": [dict(a) for a in activity],
            "export_note": "Display assets are referenced by GCS paths; use signed URLs separately.",
        }
        body = json.dumps(payload, default=_json_default, indent=2).encode("utf-8")
        object_path = f"exports/{baby_id}/{job_id}/export.json"
        client = storage.Client()
        bucket = client.bucket(settings.display_bucket)
        blob = bucket.blob(object_path)
        with get_connection() as conn:
            _touch_export_running(conn, job_id)
        blob.upload_from_string(body, content_type="application/json")
        uploaded = True

        with get_connection() as conn:
            cur = conn.execute(
                """
                UPDATE baby_data_export_jobs
                SET status = 'ready',
                    object_path = %s,
                    completed_at = now()
                WHERE id = %s
                  AND status = 'running'
                """,
                (object_path, job_id),
            )
            if getattr(cur, "rowcount", 0) == 0:
                logger.warning(
                    "export_ready_lost_claim job_id=%s path=%s",
                    job_id,
                    object_path,
                )
                _delete_export_blob(blob, object_path)
                return
        logger.info("baby_data_export_ready job_id=%s path=%s", job_id, object_path)
    except Exception:
        logger.exception(
            "baby_data_export_failed job_id=%s final_attempt=%s",
            job_id,
            final_attempt,
        )
        if uploaded and blob is not None and object_path:
            _delete_export_blob(blob, object_path)
        if claimed:
            with get_connection() as conn:
                if final_attempt:
                    _mark_export_failed(conn, job_id)
                else:
                    _release_export_claim(conn, job_id)
        raise
