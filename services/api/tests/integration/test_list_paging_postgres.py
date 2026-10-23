"""SQL paging (LIMIT/OFFSET and inbox keyset) is stable even when the sort keys tie."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.memberships import list_baby_members
from lanonna_api.repositories.notifications import list_notifications_for_user
from lanonna_api.repositories.registry import list_registry_items
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _baby_with_followers(n: int) -> uuid.UUID:
    owner = f"pg-owner-{uuid.uuid4().hex[:8]}"
    resolve_app_user(owner, f"{owner}@example.test")
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, 'Parker', 'expecting', %s)",
            (baby_id, owner),
        )
        conn.execute(
            "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
            " VALUES (%s, %s, 'owner', 'created')",
            (baby_id, owner),
        )
    for i in range(n):
        uid = f"pg-f{i}-{uuid.uuid4().hex[:8]}"
        resolve_app_user(uid, f"{uid}@example.test")
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
                " VALUES (%s, %s, 'follower', 'invite')",
                (baby_id, uid),
            )
            conn.execute(
                "INSERT INTO registry_items (baby_profile_id, created_by_firebase_uid, name)"
                " VALUES (%s, %s, %s)",
                (baby_id, owner, f"Item {i}"),
            )
    with get_connection() as conn:
        # Force ties on every sort key except the tiebreak.
        conn.execute(
            "UPDATE baby_memberships SET created_at = '2026-01-01' WHERE baby_profile_id = %s",
            (baby_id,),
        )
        conn.execute(
            "UPDATE registry_items SET created_at = '2026-01-01', priority = 3"
            " WHERE baby_profile_id = %s",
            (baby_id,),
        )
    return baby_id


def _all_pages(fetch, key: str, page: int = 2) -> list:
    seen: list = []
    offset = 0
    while True:
        rows = fetch(limit=page, offset=offset)
        seen.extend(r[key] for r in rows)
        if len(rows) < page:
            return seen
        offset += page


def test_members_and_registry_pages_cover_everything_once():
    baby_id = _baby_with_followers(5)
    members = _all_pages(lambda **kw: list_baby_members(baby_id, **kw), "firebase_uid")
    items = _all_pages(lambda **kw: list_registry_items(baby_id, **kw), "id")
    assert len(members) == len(set(members)) == 6
    assert members == [r["firebase_uid"] for r in list_baby_members(baby_id)]
    assert len(items) == len(set(items)) == 5
    assert items == [r["id"] for r in list_registry_items(baby_id)]


def test_inbox_keyset_pages_cover_ties_once_and_only_own_rows():
    me, other = (f"pg-inbox-{uuid.uuid4().hex[:8]}" for _ in range(2))
    for uid in (me, other):
        resolve_app_user(uid, f"{uid}@example.test")
    with get_connection() as conn:
        for uid, n in ((me, 7), (other, 3)):
            for i in range(n):
                # Five of mine share one timestamp so only ``id`` breaks the tie.
                at = "2026-01-01" if i < 5 else f"2026-01-0{i - 3}"
                conn.execute(
                    "INSERT INTO notifications (firebase_uid, title, body, created_at)"
                    " VALUES (%s, 'T', 'B', %s)",
                    (uid, at),
                )
    seen: list = []
    after = None
    while True:
        rows = list_notifications_for_user(me, limit=2, after=after)
        seen.extend(r["id"] for r in rows)
        if len(rows) < 2:
            break
        after = (rows[-1]["created_at"], rows[-1]["id"])
    expected = [r["id"] for r in list_notifications_for_user(me, limit=100)]
    assert len(expected) == 7
    assert seen == expected
