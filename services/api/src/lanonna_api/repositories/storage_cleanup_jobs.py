from __future__ import annotations

import json
import uuid
from enum import StrEnum
from typing import Any

from lanonna_api.db import get_connection


class StorageCleanupKind(StrEnum):
    ACCOUNT_DELETE = "account_delete"
    BABY_PROFILE_DELETE = "baby_profile_delete"


class StorageCleanupStatus(StrEnum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


def insert_storage_cleanup_job(
    *,
    kind: StorageCleanupKind,
    firebase_uid: str,
    baby_profile_ids: list[uuid.UUID],
    detached_objects: list[dict[str, str | None]],
    export_object_paths: list[str],
    conn: Any,
) -> uuid.UUID:
    job_id = uuid.uuid4()
    conn.execute(
        """
        INSERT INTO storage_cleanup_jobs (
            id, kind, firebase_uid, baby_profile_ids,
            detached_objects, export_object_paths, status
        )
        VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            job_id,
            kind.value,
            firebase_uid,
            baby_profile_ids,
            json.dumps(detached_objects),
            export_object_paths,
            StorageCleanupStatus.PENDING.value,
        ),
    )
    return job_id


def latest_account_cleanup_job_id(firebase_uid: str) -> uuid.UUID | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, status
            FROM storage_cleanup_jobs
            WHERE firebase_uid = %s
              AND kind = %s
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (firebase_uid, StorageCleanupKind.ACCOUNT_DELETE.value),
        ).fetchone()
    if row is None:
        return None
    return uuid.UUID(str(row["id"]))


def create_baby_profile_storage_cleanup_job(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    export_object_paths: list[str],
) -> uuid.UUID:
    with get_connection() as conn:
        return insert_storage_cleanup_job(
            kind=StorageCleanupKind.BABY_PROFILE_DELETE,
            firebase_uid=firebase_uid,
            baby_profile_ids=[baby_profile_id],
            detached_objects=[],
            export_object_paths=export_object_paths,
            conn=conn,
        )


def account_cleanup_job_needs_publish(firebase_uid: str) -> uuid.UUID | None:
    """Job id to publish when retrying account delete after SQL tombstone."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, status
            FROM storage_cleanup_jobs
            WHERE firebase_uid = %s
              AND kind = %s
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (firebase_uid, StorageCleanupKind.ACCOUNT_DELETE.value),
        ).fetchone()
    if row is None:
        return None
    if row["status"] == StorageCleanupStatus.COMPLETED.value:
        return None
    return uuid.UUID(str(row["id"]))
