"""Owner-initiated hard delete of a sole-owned baby profile."""

from __future__ import annotations

import uuid
from unittest.mock import patch

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.baby_delete import delete_baby_profile
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.membership_access import require_active_membership
from lanonna_api.repositories.babies import list_babies_for_user
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration


@pytest.fixture(autouse=True)
def _published_cleanup_jobs():
    with patch("lanonna_api.domain.storage_cleanup.publish_storage_cleanup") as publish:
        yield publish


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


def test_sole_owner_delete_removes_baby_from_lists_and_ends_follower_access(
    _published_cleanup_jobs,
):
    owner = _user("owner")
    follower = _user("follower")
    baby_id = _baby([(owner, "owner"), (follower, "follower")])
    _pending_invite(baby_id, owner)
    export_path = f"exports/{baby_id}/{uuid.uuid4()}/export.json"
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_data_export_jobs (
                baby_profile_id, requested_by_firebase_uid, status, object_path
            )
            VALUES (%s, %s, 'ready', %s)
            """,
            (baby_id, owner, export_path),
        )

    delete_baby_profile(owner, baby_id)

    assert list_babies_for_user(owner) == []
    assert list_babies_for_user(follower) == []

    with pytest.raises(MemberLifecycleError) as exc:
        require_active_membership(follower, baby_id)
    assert exc.value.code.value == "membership_ended"

    with get_connection() as conn:
        row = conn.execute(
            "SELECT 1 FROM baby_profiles WHERE id = %s",
            (baby_id,),
        ).fetchone()
        assert row is None
        invites = conn.execute(
            "SELECT COUNT(*)::int AS n FROM invitations WHERE baby_profile_id = %s",
            (baby_id,),
        ).fetchone()["n"]
        job = conn.execute(
            """
            SELECT id, kind, status, firebase_uid, baby_profile_ids,
                   export_object_paths, detached_objects
            FROM storage_cleanup_jobs
            """
        ).fetchone()
        exports_left = conn.execute(
            "SELECT COUNT(*)::int AS n FROM baby_data_export_jobs WHERE baby_profile_id = %s",
            (baby_id,),
        ).fetchone()["n"]
    assert invites == 0
    assert job["kind"] == "baby_profile_delete" and job["status"] == "pending"
    assert job["firebase_uid"] == owner
    assert job["baby_profile_ids"] == [baby_id]
    assert job["export_object_paths"] == [export_path]
    assert exports_left == 0
    _published_cleanup_jobs.assert_called_once_with(job["id"])


def test_co_owned_delete_refused():
    owner_a = _user("a")
    owner_b = _user("b")
    baby_id = _baby([(owner_a, "owner"), (owner_b, "owner")])

    from lanonna_api.domain.baby_delete import CannotDeleteSharedBabyError

    with pytest.raises(CannotDeleteSharedBabyError):
        delete_baby_profile(owner_a, baby_id)

    assert len(list_babies_for_user(owner_a)) == 1
    with get_connection() as conn:
        jobs = conn.execute(
            "SELECT COUNT(*)::int AS n FROM storage_cleanup_jobs"
        ).fetchone()["n"]
    assert jobs == 0


def test_co_owners_deleting_and_leaving_at_once_never_orphan_the_baby():
    """Delete and leave both take the baby row lock, so the owner count stays true."""
    import threading

    from lanonna_api.domain.baby_delete import CannotDeleteSharedBabyError
    from lanonna_api.domain.member_lifecycle import leave_baby_profile

    for _ in range(5):
        owner_a = _user("ra")
        owner_b = _user("rb")
        baby_id = _baby([(owner_a, "owner"), (owner_b, "owner")])
        barrier = threading.Barrier(2)
        errors: list[Exception] = []

        def run(fn, uid):
            barrier.wait()
            try:
                fn(uid, baby_id)
            except (CannotDeleteSharedBabyError, MemberLifecycleError) as exc:
                errors.append(exc)

        threads = [
            threading.Thread(target=run, args=(delete_baby_profile, owner_a)),
            threading.Thread(target=run, args=(leave_baby_profile, owner_b)),
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        with get_connection() as conn:
            baby = conn.execute(
                "SELECT 1 FROM baby_profiles WHERE id = %s", (baby_id,)
            ).fetchone()
            owners = conn.execute(
                """
                SELECT COUNT(*)::int AS n FROM baby_memberships
                WHERE baby_profile_id = %s AND role = 'owner' AND removed_at IS NULL
                """,
                (baby_id,),
            ).fetchone()["n"]
        # Either the delete was refused (B left, A keeps it) or B left first and A deleted.
        assert (baby is not None and owners == 1) or (baby is None and owners == 0)


def test_co_owners_leaving_at_once_keep_one_owner():
    import threading

    from lanonna_api.domain.member_lifecycle import leave_baby_profile

    for _ in range(5):
        owner_a = _user("la")
        owner_b = _user("lb")
        baby_id = _baby([(owner_a, "owner"), (owner_b, "owner")])
        barrier = threading.Barrier(2)
        refused: list[Exception] = []

        def run(uid):
            barrier.wait()
            try:
                leave_baby_profile(uid, baby_id)
            except MemberLifecycleError as exc:
                refused.append(exc)

        threads = [threading.Thread(target=run, args=(u,)) for u in (owner_a, owner_b)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(refused) == 1
        assert refused[0].code.value == "sole_owner_cannot_leave"


def test_account_delete_hard_deletes_sole_owned_babies():
    from lanonna_api.repositories.account_delete import (
        list_sole_owned_baby_ids,
        soft_delete_account_rows,
    )

    owner = _user("acct")
    follower = _user("acctf")
    baby_id = _baby([(owner, "owner"), (follower, "follower")])
    _pending_invite(baby_id, owner)

    soft_delete_account_rows(owner, list_sole_owned_baby_ids(owner))

    assert list_babies_for_user(follower) == []
    with get_connection() as conn:
        row = conn.execute(
            "SELECT 1 FROM baby_profiles WHERE id = %s", (baby_id,)
        ).fetchone()
        assert row is None
        invites = conn.execute(
            "SELECT COUNT(*)::int AS n FROM invitations WHERE baby_profile_id = %s",
            (baby_id,),
        ).fetchone()["n"]
        assert invites == 0
