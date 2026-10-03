from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def insert_export_job(
    baby_profile_id: uuid.UUID,
    requested_by_firebase_uid: str,
) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO baby_data_export_jobs (
                baby_profile_id, requested_by_firebase_uid, status
            )
            VALUES (%s, %s, 'pending')
            RETURNING id, baby_profile_id, requested_by_firebase_uid, status,
                      object_path, error_message, created_at, completed_at
            """,
            (baby_profile_id, requested_by_firebase_uid),
        ).fetchone()
    return dict(row)


def get_latest_export_job_for_baby(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, baby_profile_id, requested_by_firebase_uid, status,
                   object_path, error_message, created_at, completed_at
            FROM baby_data_export_jobs
            WHERE baby_profile_id = %s
              AND requested_by_firebase_uid = %s
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return dict(row) if row else None


def mark_export_job_failed(job_id: uuid.UUID, error_message: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE baby_data_export_jobs
            SET status = 'failed',
                error_message = %s,
                completed_at = now()
            WHERE id = %s
            """,
            (error_message[:2000], job_id),
        )
