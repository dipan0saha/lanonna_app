from __future__ import annotations

import uuid
from enum import StrEnum

from lanonna_api.db import get_connection
from lanonna_api.repositories.memberships import (
    count_active_owners,
    lock_baby_profile_for_update,
    lock_membership_for_user_for_update,
    soft_remove_memberships_on_babies,
)


class SoleOwnerDeleteOutcome(StrEnum):
    DELETED = "deleted"
    NOT_OWNER = "not_owner"
    SHARED = "shared"


def soft_delete_baby_profiles(
    baby_profile_ids: list[uuid.UUID],
    conn=None,
) -> None:
    """Soft-delete baby profiles and end all memberships on them.

    Same SQL slice used for sole-owned babies during account delete and for
    explicit owner-initiated baby profile deletion.
    """
    if not baby_profile_ids:
        return

    def _run(connection) -> None:
        connection.execute(
            """
            UPDATE invitations
            SET status = 'revoked', updated_at = now()
            WHERE baby_profile_id = ANY(%s::uuid[]) AND status = 'pending'
            """,
            (baby_profile_ids,),
        )
        soft_remove_memberships_on_babies(baby_profile_ids, conn=connection)
        connection.execute(
            """
            UPDATE baby_profiles
            SET deleted_at = now(), updated_at = now()
            WHERE id = ANY(%s::uuid[]) AND deleted_at IS NULL
            """,
            (baby_profile_ids,),
        )

    if conn is not None:
        _run(conn)
    else:
        with get_connection() as connection:
            _run(connection)


def soft_delete_baby_profile_if_sole_owner(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> SoleOwnerDeleteOutcome:
    """Check sole ownership and delete in one transaction.

    The baby row lock (``lock_baby_profile_for_update``) is the same lock
    co-owner invite and accept take, so an owner joining or leaving cannot
    change the owner count between the check and the delete.
    """
    with get_connection() as conn:
        if lock_baby_profile_for_update(baby_profile_id, conn) is None:
            return SoleOwnerDeleteOutcome.NOT_OWNER
        membership = lock_membership_for_user_for_update(
            baby_profile_id, firebase_uid, conn
        )
        if membership is None or membership["role"] != "owner":
            return SoleOwnerDeleteOutcome.NOT_OWNER
        if count_active_owners(baby_profile_id, conn) > 1:
            return SoleOwnerDeleteOutcome.SHARED
        soft_delete_baby_profiles([baby_profile_id], conn=conn)
        return SoleOwnerDeleteOutcome.DELETED
