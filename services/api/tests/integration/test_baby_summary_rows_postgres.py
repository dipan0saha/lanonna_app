"""Every baby summary write returns the caller's stored membership fields.

PATCH and announce-arrival used to hand-fill ``relationship_label = None`` after
the UPDATE, so the app lost the owner's relationship until the next list
reload. All summary rows now come from one column list.
"""

from __future__ import annotations

import uuid
from datetime import date

import pytest

from lanonna_api.domain.baby_summaries import baby_summary_from_row
from lanonna_api.repositories.babies import (
    create_baby_with_owner_membership,
    get_baby_for_owner,
    get_baby_membership,
    list_babies_for_user,
    update_baby_for_owner,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(tag: str) -> str:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    return uid


def test_create_patch_and_reads_share_relationship_and_role():
    owner = _user("owner")
    created = create_baby_with_owner_membership(
        owner, "Parker", "male", None, None, "expecting", "Mother"
    )
    baby_id = created["id"]

    patched = update_baby_for_owner(owner, baby_id, {"name": "Rowan"})
    born = update_baby_for_owner(
        owner,
        baby_id,
        {"lifecycle_status": "born", "actual_birth_date": date(2026, 1, 2)},
    )
    listed = next(r for r in list_babies_for_user(owner) if r["id"] == baby_id)

    for row in (created, patched, born, get_baby_for_owner(owner, baby_id), listed):
        assert row is not None
        summary = baby_summary_from_row(row)
        assert summary.relationship_label == "Mother"
        assert summary.role == "owner"
        assert summary.can_leave is False
    assert patched["name"] == "Rowan"
    assert born["lifecycle_status"] == "born"
    assert set(created) == set(patched) == set(listed)


def test_membership_read_returns_the_followers_own_relationship():
    owner, follower = _user("owner"), _user("follower")
    baby_id = create_baby_with_owner_membership(
        owner, "Parker", None, None, None, "expecting", "Father"
    )["id"]
    from lanonna_api.db import get_connection

    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_memberships"
            " (baby_profile_id, firebase_uid, role, relationship_label, joined_via)"
            " VALUES (%s, %s, 'follower', 'Grandma', 'invite')",
            (baby_id, follower),
        )

    row = get_baby_membership(follower, baby_id)
    assert row is not None
    assert row["role"] == "follower"
    assert row["relationship_label"] == "Grandma"
    assert get_baby_for_owner(follower, baby_id) is None
    assert update_baby_for_owner(follower, baby_id, {"name": "Nope"}) is None
