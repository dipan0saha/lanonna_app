"""Gallery list sort modes used by the All / Recent / Favorites selector (#393)."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.photos import list_photos_for_baby
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

OWNER = "sort-owner"
FOLLOWER = "sort-follower"


def _seed() -> tuple[uuid.UUID, dict[str, uuid.UUID]]:
    resolve_app_user(OWNER, "sort-owner@example.com")
    resolve_app_user(FOLLOWER, "sort-follower@example.com")
    baby_id = uuid.uuid4()
    photos = {name: uuid.uuid4() for name in ("old_popular", "new_liked", "newest")}
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Parker', 'expecting', %s)
            """,
            (baby_id, OWNER),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created'), (%s, %s, 'follower', 'invite')
            """,
            (baby_id, OWNER, baby_id, FOLLOWER),
        )
        for name, age in (("old_popular", "40 days"), ("new_liked", "1 day"), ("newest", "0 days")):
            conn.execute(
                """
                INSERT INTO photos (
                    id, baby_profile_id, uploader_firebase_uid, status, caption, created_at
                )
                VALUES (%s, %s, %s, 'ready', %s, now() - %s::interval)
                """,
                (photos[name], baby_id, OWNER, name, age),
            )
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid)
            VALUES (%s, %s), (%s, %s), (%s, %s)
            """,
            (
                photos["old_popular"], OWNER,
                photos["old_popular"], FOLLOWER,
                photos["new_liked"], FOLLOWER,
            ),
        )
    return baby_id, photos


def _ids(baby_id: uuid.UUID, sort: str) -> list[uuid.UUID]:
    return [r["id"] for r in list_photos_for_baby(baby_id, ready_only=True, sort=sort)]


def test_default_recent_and_favorites_sorts():
    baby_id, p = _seed()
    assert _ids(baby_id, "default") == [p["newest"], p["new_liked"], p["old_popular"]]
    # Recent: last 30 days, newest first.
    assert _ids(baby_id, "recent") == [p["newest"], p["new_liked"]]
    # Favorites: squished photos only, most squishes first.
    assert _ids(baby_id, "favorites") == [p["old_popular"], p["new_liked"]]
