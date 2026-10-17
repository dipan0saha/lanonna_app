"""Owner limit (domain/owner_limit.py) on real Postgres: batch invite and accept."""

from __future__ import annotations

import uuid
from unittest.mock import patch

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.invitations import BatchInviteRow, batch_invite
from lanonna_api.domain.owner_limit import MaxOwnersError
from lanonna_api.repositories.invitations import accept_invitation_by_token, _hash_token
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(tag: str) -> tuple[str, str]:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    email = f"{uid}@example.test"
    resolve_app_user(uid, email)
    return uid, email


def _baby(*owners: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, 'Parker', 'expecting', %s)",
            (baby_id, owners[0]),
        )
        for owner in owners:
            conn.execute(
                "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
                " VALUES (%s, %s, 'owner', 'created')",
                (baby_id, owner),
            )
    return baby_id


def _owner_invite(baby_id: uuid.UUID, inviter: str, email: str, *, expired: bool = False) -> str:
    token = uuid.uuid4().hex
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO invitations (baby_profile_id, inviter_firebase_uid, invitee_email,"
            " role, relationship_label, token_hash, expires_at)"
            " VALUES (%s, %s, %s, 'owner', 'Father', %s,"
            " CASE WHEN %s THEN now() - interval '1 day' ELSE now() + interval '1 day' END)",
            (baby_id, inviter, email, _hash_token(token), expired),
        )
    return token


def _invite(owner: str, baby_id: uuid.UUID, rows: list[BatchInviteRow]):
    with patch("lanonna_api.domain.invitations.publish_send_invite_email"):
        return [(r["email"], r["status"]) for r in batch_invite(owner, baby_id, rows)]


def test_batch_invite_allows_one_co_owner_invite_per_free_slot():
    owner, _ = _user("owner")
    baby_id = _baby(owner)
    results = _invite(
        owner,
        baby_id,
        [
            BatchInviteRow("dad@example.test", "owner", "Father"),
            BatchInviteRow("aunt@example.test", "follower", "Aunt"),
            BatchInviteRow("mum@example.test", "owner", "Mother"),
        ],
    )
    assert results == [
        ("dad@example.test", "created"),
        ("aunt@example.test", "created"),
        ("mum@example.test", "skipped_max_owners"),
    ]


def test_pending_owner_invite_reserves_the_slot_until_it_expires():
    owner, _ = _user("owner")
    baby_id = _baby(owner)
    _owner_invite(baby_id, owner, "first@example.test")
    assert _invite(owner, baby_id, [BatchInviteRow("second@example.test", "owner", "Mother")]) == [
        ("second@example.test", "skipped_max_owners"),
    ]

    other_baby = _baby(owner)
    _owner_invite(other_baby, owner, "stale@example.test", expired=True)
    assert _invite(owner, other_baby, [BatchInviteRow("fresh@example.test", "owner", "Mother")]) == [
        ("fresh@example.test", "created"),
    ]


def test_full_baby_skips_owner_rows_but_still_invites_followers():
    owner, _ = _user("owner")
    co_owner, _ = _user("coowner")
    baby_id = _baby(owner, co_owner)
    assert _invite(
        owner,
        baby_id,
        [
            BatchInviteRow("dad@example.test", "owner", "Father"),
            BatchInviteRow("gran@example.test", "follower", "Grandma"),
        ],
    ) == [
        ("dad@example.test", "skipped_max_owners"),
        ("gran@example.test", "created"),
    ]


def test_accept_owner_invite_on_full_baby_raises_max_owners():
    owner, _ = _user("owner")
    invitee, invitee_email = _user("invitee")
    baby_id = _baby(owner)
    token = _owner_invite(baby_id, owner, invitee_email)
    late_owner, _ = _user("late")
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
            " VALUES (%s, %s, 'owner', 'invite')",
            (baby_id, late_owner),
        )
    with pytest.raises(MaxOwnersError):
        accept_invitation_by_token(token, invitee, invitee_email)
    with get_connection() as conn:
        status = conn.execute(
            "SELECT status FROM invitations WHERE token_hash = %s", (_hash_token(token),)
        ).fetchone()["status"]
    assert status == "pending"
