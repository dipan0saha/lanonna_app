"""Baby list rows carry active owner counts from one statement (no N+1)."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.baby_summaries import baby_summary_from_row
from lanonna_api.repositories.babies import (
    get_baby_for_owner,
    list_babies_for_user,
    update_baby_for_owner,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(tag: str) -> str:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    return uid


def _baby(members: list[tuple[str, str, bool]]) -> uuid.UUID:
    """members: (uid, role, removed)."""
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, 'Parker', 'expecting', %s)",
            (baby_id, members[0][0]),
        )
        for uid, role, removed in members:
            conn.execute(
                "INSERT INTO baby_memberships"
                " (baby_profile_id, firebase_uid, role, joined_via, removed_at)"
                " VALUES (%s, %s, %s, 'created', CASE WHEN %s THEN now() END)",
                (baby_id, uid, role, removed),
            )
    return baby_id


def test_list_rows_count_only_active_owners_per_baby():
    me, co_owner, gone, other = _user("me"), _user("co"), _user("gone"), _user("other")
    sole = _baby([(me, "owner", False), (gone, "owner", True)])
    shared = _baby([(me, "owner", False), (co_owner, "owner", False)])
    following = _baby([(other, "owner", False), (me, "follower", False)])

    rows = {row["id"]: row for row in list_babies_for_user(me)}

    assert rows[sole]["active_owner_count"] == 1
    assert rows[shared]["active_owner_count"] == 2
    assert rows[following]["active_owner_count"] == 1
    can_leave = {bid: baby_summary_from_row(r).can_leave for bid, r in rows.items()}
    assert can_leave == {sole: False, shared: True, following: True}


def test_single_baby_owner_reads_carry_the_same_count():
    me, co_owner = _user("me"), _user("co")
    baby = _baby([(me, "owner", False), (co_owner, "owner", False)])

    assert get_baby_for_owner(me, baby)["active_owner_count"] == 2
    updated = update_baby_for_owner(me, baby, {"name": "Rowan"})
    assert updated is not None and updated["active_owner_count"] == 2
    assert baby_summary_from_row(updated).can_leave is True
