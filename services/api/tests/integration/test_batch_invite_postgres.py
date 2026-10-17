"""Batch invites against real Postgres: set-based checks, one write transaction."""

from __future__ import annotations

import uuid
from unittest.mock import patch

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.invitations import (
    BatchInviteRow,
    batch_invite,
    membership_check_for_owner,
)
from lanonna_api.repositories.invitations import write_batch_invitations
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(tag: str) -> tuple[str, str]:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    email = f"{uid}@example.test"
    resolve_app_user(uid, email)
    return uid, email


def _baby(owner: str, follower: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, 'Parker', 'expecting', %s)",
            (baby_id, owner),
        )
        conn.execute(
            "INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)"
            " VALUES (%s, %s, 'owner', 'created'), (%s, %s, 'follower', 'invite')",
            (baby_id, owner, baby_id, follower),
        )
    return baby_id


def _pending(baby_id: uuid.UUID, inviter: str, email: str, *, sent: bool) -> uuid.UUID:
    inv_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO invitations (id, baby_profile_id, inviter_firebase_uid, invitee_email,"
            " role, token_hash, expires_at, email_sent_at, email_delivery_status)"
            " VALUES (%s, %s, %s, %s, 'follower', %s, now() + interval '1 day',"
            " CASE WHEN %s THEN now() END, CASE WHEN %s THEN 'sent' ELSE 'failed' END)",
            (inv_id, baby_id, inviter, email, uuid.uuid4().hex, sent, sent),
        )
    return inv_id


def test_batch_invite_rows_get_their_own_results_in_order():
    owner, _ = _user("owner")
    follower, follower_email = _user("follower")
    baby_id = _baby(owner, follower)
    sent_id = _pending(baby_id, owner, "sent@example.test", sent=True)
    unsent_id = _pending(baby_id, owner, "unsent@example.test", sent=False)

    with patch("lanonna_api.domain.invitations.publish_send_invite_email") as publish:
        results = batch_invite(
            owner,
            baby_id,
            [
                BatchInviteRow(follower_email.upper(), "follower", None),
                BatchInviteRow("sent@example.test", "follower", None),
                BatchInviteRow(" Unsent@Example.test ", "follower", None),
                BatchInviteRow("new@example.test", "owner", "Father"),
                BatchInviteRow("NEW@example.test", "follower", "Aunt"),
            ],
        )

    statuses = [(r["email"], r["status"]) for r in results]
    assert statuses == [
        (follower_email, "skipped_member"),
        ("sent@example.test", "skipped_duplicate"),
        ("unsent@example.test", "resent"),
        ("new@example.test", "created"),
        ("new@example.test", "skipped_duplicate"),
    ]
    assert results[1]["invitation_id"] == sent_id
    assert results[2]["invitation_id"] == unsent_id
    new_id = results[3]["invitation_id"]
    assert [c.args[0] for c in publish.call_args_list] == [unsent_id, new_id]

    with get_connection() as conn:
        created = conn.execute(
            "SELECT invitee_email, role, relationship_label, status, email_invite_token,"
            " token_hash, expires_at > now() + interval '13 days' AS fresh"
            " FROM invitations WHERE id = %s",
            (new_id,),
        ).fetchone()
        rearmed = conn.execute(
            "SELECT email_delivery_status FROM invitations WHERE id = %s", (unsent_id,)
        ).fetchone()
    assert created["invitee_email"] == "new@example.test"
    assert (created["role"], created["relationship_label"]) == ("owner", "Father")
    assert created["status"] == "pending" and created["fresh"] is True
    assert created["email_invite_token"] and created["token_hash"]
    assert rearmed["email_delivery_status"] == "pending"

    check = membership_check_for_owner(owner, baby_id, "New@Example.test")
    assert check == {"is_member": False, "has_pending_invite": True}
    assert membership_check_for_owner(owner, baby_id, follower_email) == {
        "is_member": True,
        "has_pending_invite": False,
    }


def test_concurrent_pending_invite_is_skipped_not_raised():
    owner, _ = _user("owner")
    follower, _ = _user("follower")
    baby_id = _baby(owner, follower)
    _pending(baby_id, owner, "race@example.test", sent=False)

    prepared, created, over_owner_limit = write_batch_invitations(
        baby_id,
        owner,
        resend_ids=[],
        new_invites=[("race@example.test", "follower", None), ("ok@example.test", "follower", None)],
    )

    assert prepared == set()
    assert list(created) == ["ok@example.test"]
    assert over_owner_limit == set()
