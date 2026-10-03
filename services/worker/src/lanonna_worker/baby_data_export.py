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


def _json_default(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    return str(value)


def run_baby_data_export(job_id: uuid.UUID) -> None:
    with get_connection() as conn:
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
        if job["status"] not in ("pending", "running"):
            return
        conn.execute(
            "UPDATE baby_data_export_jobs SET status = 'running' WHERE id = %s",
            (job_id,),
        )
        baby_id = job["baby_profile_id"]

        baby = conn.execute(
            "SELECT * FROM baby_profiles WHERE id = %s",
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
            "SELECT * FROM events WHERE baby_profile_id = %s ORDER BY starts_at",
            (baby_id,),
        ).fetchall()
        registry = conn.execute(
            "SELECT * FROM registry_items WHERE baby_profile_id = %s ORDER BY created_at",
            (baby_id,),
        ).fetchall()
        names = conn.execute(
            "SELECT * FROM name_suggestions WHERE baby_profile_id = %s ORDER BY created_at",
            (baby_id,),
        ).fetchall()
        activity = conn.execute(
            """
            SELECT * FROM activity_events
            WHERE baby_profile_id = %s
            ORDER BY created_at DESC
            LIMIT 500
            """,
            (baby_id,),
        ).fetchall()

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
    blob.upload_from_string(body, content_type="application/json")

    with get_connection() as conn:
        conn.execute(
            """
            UPDATE baby_data_export_jobs
            SET status = 'ready', object_path = %s, completed_at = now()
            WHERE id = %s
            """,
            (object_path, job_id),
        )
    logger.info("baby_data_export_ready job_id=%s path=%s", job_id, object_path)
