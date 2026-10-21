"""Hard-delete removes all baby-scoped rows; other babies stay intact."""

from __future__ import annotations

import uuid
from unittest.mock import patch

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.baby_delete import delete_baby_profile
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


@pytest.fixture(autouse=True)
def _published_cleanup_jobs():
    with patch("lanonna_api.domain.storage_cleanup.publish_storage_cleanup"):
        yield


def _user(tag: str) -> str:
    uid = f"hard-del-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    return uid


def _sole_baby(owner: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Cascade Baby', 'expecting', %s)
            """,
            (baby_id, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, owner),
        )
    return baby_id


def test_hard_delete_removes_follower_content_and_leaves_other_baby_alone():
    owner = _user("owner")
    follower = _user("follower")
    other_owner = _user("other")
    doomed = _sole_baby(owner)
    survivor = _sole_baby(other_owner)
    photo_id = uuid.uuid4()
    event_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'follower', 'invite')
            """,
            (doomed, follower),
        )
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
                doomed,
                follower,
                f"display/{photo_id}.webp",
                f"thumbnails/{photo_id}.jpg",
            ),
        )
        conn.execute(
            """
            INSERT INTO events (
                id, baby_profile_id, created_by_firebase_uid, title, starts_at
            )
            VALUES (%s, %s, %s, 'Shower', now())
            """,
            (event_id, doomed, owner),
        )
        conn.execute(
            """
            INSERT INTO event_rsvps (event_id, firebase_uid, status)
            VALUES (%s, %s, 'going')
            """,
            (event_id, follower),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (photo_id, author_firebase_uid, body)
            VALUES (%s, %s, 'Sweet!')
            """,
            (photo_id, follower),
        )
        conn.execute(
            """
            INSERT INTO notifications (
                firebase_uid, baby_profile_id, title, body, notification_type
            )
            VALUES (%s, %s, 'Hi', 'Body', 'generic')
            """,
            (follower, doomed),
        )

    delete_baby_profile(owner, doomed)

    with get_connection() as conn:
        assert conn.execute(
            "SELECT 1 FROM baby_profiles WHERE id = %s", (doomed,)
        ).fetchone() is None
        assert conn.execute(
            "SELECT 1 FROM baby_profiles WHERE id = %s", (survivor,)
        ).fetchone() is not None
        assert conn.execute("SELECT COUNT(*)::int AS n FROM photos").fetchone()["n"] == 0
        assert (
            conn.execute("SELECT COUNT(*)::int AS n FROM event_rsvps").fetchone()["n"]
            == 0
        )
        assert (
            conn.execute(
                "SELECT COUNT(*)::int AS n FROM notifications WHERE baby_profile_id = %s",
                (doomed,),
            ).fetchone()["n"]
            == 0
        )
        job = conn.execute(
            """
            SELECT detached_objects FROM storage_cleanup_jobs
            ORDER BY created_at DESC LIMIT 1
            """
        ).fetchone()
    paths = {o["display_path"] for o in job["detached_objects"]}
    assert paths == {f"display/{photo_id}.webp"}
