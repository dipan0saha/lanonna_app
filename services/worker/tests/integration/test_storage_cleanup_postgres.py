"""storage_cleanup_jobs claim, completion and sweep against real Postgres (GCS mocked)."""

from __future__ import annotations

import json
import uuid
from unittest.mock import patch

from lanonna_worker.db import get_connection
from lanonna_worker.storage_cleanup import run_storage_cleanup, sweep_storage_cleanup_jobs


def _job(uid: str, *, status: str = "pending", age: str = "0 minutes") -> uuid.UUID:
    job_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO app_users (firebase_uid) VALUES (%s) ON CONFLICT DO NOTHING",
            (uid,),
        )
        conn.execute(
            """
            INSERT INTO storage_cleanup_jobs (
                id, kind, firebase_uid, detached_objects, status,
                created_at, started_at, completed_at
            )
            VALUES (%s, 'baby_profile_delete', %s, %s::jsonb, %s,
                    now() - %s::interval, now() - %s::interval, now() - %s::interval)
            """,
            (
                job_id,
                uid,
                json.dumps([{"display_path": "display/x.jpg", "thumb_path": None}]),
                status,
                age,
                age,
                age,
            ),
        )
    return job_id


def _status(job_id: uuid.UUID) -> dict:
    with get_connection() as conn:
        return conn.execute(
            "SELECT status, objects_deleted_count FROM storage_cleanup_jobs WHERE id = %s",
            (job_id,),
        ).fetchone()


def test_run_completes_job_once():
    job_id = _job("sc-run")
    with patch(
        "lanonna_worker.storage_cleanup.gcs_delete.delete_photo_paths", return_value=1
    ) as delete:
        run_storage_cleanup(job_id)
        run_storage_cleanup(job_id)  # duplicate delivery: already completed

    assert _status(job_id) == {"status": "completed", "objects_deleted_count": 1}
    delete.assert_called_once()


def test_sweep_picks_only_stuck_jobs():
    fresh = _job("sc-fresh")
    lost_publish = _job("sc-lost", age="20 minutes")
    stuck_running = _job("sc-stuck", status="running", age="40 minutes")
    failed_long_ago = _job("sc-failed", status="failed", age="7 hours")
    failed_recently = _job("sc-failed-new", status="failed", age="1 hour")

    with patch(
        "lanonna_worker.storage_cleanup.gcs_delete.delete_photo_paths", return_value=1
    ):
        assert sweep_storage_cleanup_jobs() == 3

    for job_id in (lost_publish, stuck_running, failed_long_ago):
        assert _status(job_id)["status"] == "completed"
    assert _status(fresh)["status"] == "pending"
    assert _status(failed_recently)["status"] == "failed"
