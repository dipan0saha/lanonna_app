"""Account delete removes authored photos on shared babies and enqueues storage cleanup."""

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.account_delete import (
    list_sole_owned_baby_ids,
    soft_delete_account_rows,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(uid: str) -> None:
    resolve_app_user(uid, f"{uid}@example.com")


def _baby(owner: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Shared', 'expecting', %s)
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role, joined_via
            )
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, owner),
        )
    return baby_id


def _member(baby_id: uuid.UUID, uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'follower', 'invite')
            """,
            (baby_id, uid),
        )


def test_account_delete_removes_shared_upload_and_creates_cleanup_job():
    owner = "store-owner"
    uploader = "store-uploader"
    _user(owner)
    _user(uploader)
    baby_id = _baby(owner)
    _member(baby_id, uploader)
    photo_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status,
                display_path, thumb_path, purpose
            )
            VALUES (%s, %s, %s, 'ready', %s, %s, 'gallery')
            """,
            (
                photo_id,
                baby_id,
                uploader,
                f"display/{photo_id}.webp",
                f"thumbnails/{photo_id}.jpg",
            ),
        )

    job_id = soft_delete_account_rows(uploader, list_sole_owned_baby_ids(uploader))

    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*)::int AS n FROM photos WHERE id = %s",
            (photo_id,),
        ).fetchone()
        assert row["n"] == 0
        job = conn.execute(
            """
            SELECT kind, status, detached_objects, firebase_uid
            FROM storage_cleanup_jobs
            WHERE id = %s
            """,
            (job_id,),
        ).fetchone()
    assert job["kind"] == "account_delete"
    assert job["status"] == "pending"
    assert job["firebase_uid"] == uploader
    assert job["detached_objects"][0]["display_path"] == f"display/{photo_id}.webp"
