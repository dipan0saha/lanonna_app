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


def test_account_delete_hard_deletes_sole_owned_baby_and_collects_photo_paths():
    owner = "store-sole-owner"
    other = "store-other-owner"
    _user(owner)
    _user(other)
    sole_baby = _baby(owner)
    other_baby = _baby(other)
    _member(other_baby, owner)
    sole_photo = uuid.uuid4()
    other_photo = uuid.uuid4()
    others_own_photo = uuid.uuid4()
    with get_connection() as conn:
        for photo_id, baby_id, uploader in (
            (sole_photo, sole_baby, owner),
            (other_photo, other_baby, owner),
            (others_own_photo, other_baby, other),
        ):
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
        conn.execute(
            """
            INSERT INTO events (id, baby_profile_id, created_by_firebase_uid, title,
                                starts_at, cover_photo_id)
            VALUES (%s, %s, %s, 'Party', now(), %s)
            """,
            (uuid.uuid4(), other_baby, other, other_photo),
        )
        conn.execute(
            """
            INSERT INTO baby_data_export_jobs (
                baby_profile_id, requested_by_firebase_uid, status, object_path
            )
            VALUES (%s, %s, 'ready', %s), (%s, %s, 'ready', %s)
            """,
            (
                sole_baby, owner, f"exports/{sole_baby}/a/export.json",
                other_baby, other, f"exports/{other_baby}/b/export.json",
            ),
        )

    job_id = soft_delete_account_rows(owner, list_sole_owned_baby_ids(owner))

    with get_connection() as conn:
        remaining = {
            row["id"]
            for row in conn.execute("SELECT id FROM photos").fetchall()
        }
        cover = conn.execute(
            "SELECT cover_photo_id FROM events WHERE baby_profile_id = %s",
            (other_baby,),
        ).fetchone()["cover_photo_id"]
        exports = [
            row["baby_profile_id"]
            for row in conn.execute(
                "SELECT baby_profile_id FROM baby_data_export_jobs"
            ).fetchall()
        ]
        job = conn.execute(
            """
            SELECT baby_profile_ids, detached_objects, export_object_paths
            FROM storage_cleanup_jobs WHERE id = %s
            """,
            (job_id,),
        ).fetchone()
    assert remaining == {others_own_photo}
    assert cover is None
    assert exports == [other_baby]
    assert job["baby_profile_ids"] == [sole_baby]
    assert {o["display_path"] for o in job["detached_objects"]} == {
        f"display/{other_photo}.webp",
        f"display/{sole_photo}.webp",
    }
    assert job["export_object_paths"] == [f"exports/{sole_baby}/a/export.json"]
    with get_connection() as conn:
        sole_row = conn.execute(
            "SELECT 1 FROM baby_profiles WHERE id = %s", (sole_baby,)
        ).fetchone()
    assert sole_row is None
