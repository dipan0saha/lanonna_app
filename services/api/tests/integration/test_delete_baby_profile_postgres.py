"""Owner-initiated soft delete of a sole-owned baby profile."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.baby_delete import delete_baby_profile
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.membership_access import require_active_membership
from lanonna_api.repositories.babies import list_babies_for_user
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


def _user(tag: str) -> str:
    uid = f"del-baby-{tag}-{uuid.uuid4().hex[:8]}"
    resolve_app_user(uid, f"{uid}@example.test")
    return uid


def _baby(members: list[tuple[str, str]]) -> uuid.UUID:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Test Baby', 'expecting', %s)
            """,
            (baby_id, members[0][0]),
        )
        for uid, role in members:
            conn.execute(
                """
                INSERT INTO baby_memberships
                (baby_profile_id, firebase_uid, role, joined_via)
                VALUES (%s, %s, %s, 'created')
                """,
                (baby_id, uid, role),
            )
    return baby_id


def _pending_invite(baby_id: uuid.UUID, owner_uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO invitations (
                id, baby_profile_id, inviter_firebase_uid, invitee_email,
                role, token_hash, expires_at
            )
            VALUES (%s, %s, %s, 'follower@example.test', 'follower', %s, now() + interval '7 days')
            """,
            (uuid.uuid4(), baby_id, owner_uid, uuid.uuid4().hex),
        )


def test_sole_owner_delete_removes_baby_from_lists_and_ends_follower_access():
    owner = _user("owner")
    follower = _user("follower")
    baby_id = _baby([(owner, "owner"), (follower, "follower")])
    _pending_invite(baby_id, owner)

    delete_baby_profile(owner, baby_id)

    assert list_babies_for_user(owner) == []
    assert list_babies_for_user(follower) == []

    with pytest.raises(MemberLifecycleError) as exc:
        require_active_membership(follower, baby_id)
    assert exc.value.code.value == "membership_ended"

    with get_connection() as conn:
        row = conn.execute(
            "SELECT deleted_at FROM baby_profiles WHERE id = %s",
            (baby_id,),
        ).fetchone()
        assert row is not None and row["deleted_at"] is not None
        pending = conn.execute(
            "SELECT status FROM invitations WHERE baby_profile_id = %s",
            (baby_id,),
        ).fetchone()
        assert pending is not None and pending["status"] == "revoked"


def test_co_owned_delete_refused():
    owner_a = _user("a")
    owner_b = _user("b")
    baby_id = _baby([(owner_a, "owner"), (owner_b, "owner")])

    from lanonna_api.domain.baby_delete import CannotDeleteSharedBabyError

    with pytest.raises(CannotDeleteSharedBabyError):
        delete_baby_profile(owner_a, baby_id)

    assert len(list_babies_for_user(owner_a)) == 1
