"""Accept by an existing member is a read-only no-op on real Postgres (#374).

Membership is checked before the invitee email, so a member who opens a link
addressed to someone else lands on the baby. That path must never consume the
invite, change its status, or change the member's role. Non-members still get
the email check first, then the status checks.
"""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.errors import DomainError, ErrorCode
from lanonna_api.repositories.invitations import _hash_token, accept_invitation_by_token
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(tag: str) -> tuple[str, str]:
    uid = f"pg-{tag}-{uuid.uuid4().hex[:8]}"
    email = f"{uid}@example.test"
    resolve_app_user(uid, email)
    return uid, email


def _baby(owner: str) -> uuid.UUID:
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
    return baby_id


def _add_follower(baby_id: uuid.UUID, uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_memberships"
            " (baby_profile_id, firebase_uid, role, relationship_label, joined_via)"
            " VALUES (%s, %s, 'follower', 'Aunt', 'invite')",
            (baby_id, uid),
        )


def _invite(
    baby_id: uuid.UUID,
    inviter: str,
    email: str,
    *,
    role: str = "owner",
    status: str = "pending",
    expired: bool = False,
) -> str:
    token = uuid.uuid4().hex
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO invitations (baby_profile_id, inviter_firebase_uid, invitee_email,"
            " role, relationship_label, token_hash, status, expires_at)"
            " VALUES (%s, %s, %s, %s, 'Father', %s, %s,"
            " CASE WHEN %s THEN now() - interval '1 day' ELSE now() + interval '1 day' END)",
            (baby_id, inviter, email, role, _hash_token(token), status, expired),
        )
    return token


def _invite_state(token: str) -> tuple[str, object]:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT status, updated_at FROM invitations WHERE token_hash = %s",
            (_hash_token(token),),
        ).fetchone()
    return row["status"], row["updated_at"]


def _memberships(baby_id: uuid.UUID) -> list[tuple[str, str]]:
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT firebase_uid, role FROM baby_memberships"
            " WHERE baby_profile_id = %s AND removed_at IS NULL ORDER BY firebase_uid",
            (baby_id,),
        ).fetchall()
    return [(r["firebase_uid"], r["role"]) for r in rows]


def test_member_opening_pending_owner_invite_for_someone_else_changes_nothing():
    owner, _ = _user("owner")
    follower, follower_email = _user("follower")
    invitee, invitee_email = _user("invitee")
    baby_id = _baby(owner)
    _add_follower(baby_id, follower)
    token = _invite(baby_id, owner, invitee_email, role="owner")
    before_invite = _invite_state(token)
    before_members = _memberships(baby_id)

    result = accept_invitation_by_token(token, follower, follower_email)

    assert result == {
        "already_member": True,
        "baby_profile_id": baby_id,
        "role": "follower",
        "baby_name": "Parker",
    }
    assert _invite_state(token) == before_invite
    assert before_invite[0] == "pending"
    assert _memberships(baby_id) == before_members

    # The real invitee can still use it afterwards.
    accepted = accept_invitation_by_token(token, invitee, invitee_email)
    assert accepted["already_member"] is False
    assert accepted["role"] == "owner"
    assert _invite_state(token)[0] == "accepted"


@pytest.mark.parametrize(
    ("status", "expired"),
    [("revoked", False), ("expired", False), ("pending", True), ("accepted", False)],
)
def test_member_opening_closed_invite_is_a_no_op(status: str, expired: bool):
    owner, owner_email = _user("owner")
    _, invitee_email = _user("invitee")
    baby_id = _baby(owner)
    token = _invite(baby_id, owner, invitee_email, role="follower", status=status, expired=expired)
    before_invite = _invite_state(token)

    result = accept_invitation_by_token(token, owner, owner_email)

    assert result["already_member"] is True
    assert result["role"] == "owner"
    assert _invite_state(token) == before_invite
    assert _memberships(baby_id) == [(owner, "owner")]


@pytest.mark.parametrize(
    ("status", "expired", "code"),
    [
        ("revoked", False, ErrorCode.REVOKED),
        ("expired", False, ErrorCode.EXPIRED),
        ("pending", True, ErrorCode.EXPIRED),
        ("accepted", False, ErrorCode.ALREADY_USED),
    ],
)
def test_non_member_invitee_still_gets_status_refusals(status: str, expired: bool, code):
    owner, _ = _user("owner")
    invitee, invitee_email = _user("invitee")
    baby_id = _baby(owner)
    token = _invite(baby_id, owner, invitee_email, role="follower", status=status, expired=expired)
    before_invite = _invite_state(token)

    with pytest.raises(DomainError) as exc:
        accept_invitation_by_token(token, invitee, invitee_email)

    assert exc.value.code == code
    assert _invite_state(token) == before_invite
    assert _memberships(baby_id) == [(owner, "owner")]


@pytest.mark.parametrize("status", ["pending", "revoked", "accepted"])
def test_non_member_with_other_email_gets_email_mismatch_first(status: str):
    owner, _ = _user("owner")
    stranger, stranger_email = _user("stranger")
    _, invitee_email = _user("invitee")
    baby_id = _baby(owner)
    token = _invite(baby_id, owner, invitee_email, role="follower", status=status)
    before_invite = _invite_state(token)

    with pytest.raises(DomainError) as exc:
        accept_invitation_by_token(token, stranger, stranger_email)

    assert exc.value.code == ErrorCode.EMAIL_MISMATCH
    assert _invite_state(token) == before_invite
    assert _memberships(baby_id) == [(owner, "owner")]
