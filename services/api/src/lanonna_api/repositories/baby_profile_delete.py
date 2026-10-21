from __future__ import annotations

import uuid
from enum import StrEnum

from lanonna_api.db import get_connection
from lanonna_api.repositories.account_delete_media import (
    collect_and_delete_export_jobs,
    collect_photo_storage_for_babies,
    hard_delete_baby_profiles,
)
from lanonna_api.repositories.memberships import (
    count_active_owners,
    lock_baby_profile_for_update,
    lock_membership_for_user_for_update,
)
from lanonna_api.repositories.storage_cleanup_jobs import (
    StorageCleanupKind,
    insert_storage_cleanup_job,
)


class SoleOwnerDeleteOutcome(StrEnum):
    DELETED = "deleted"
    NOT_OWNER = "not_owner"
    SHARED = "shared"


def hard_delete_baby_profile_if_sole_owner(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> tuple[SoleOwnerDeleteOutcome, uuid.UUID | None]:
    """Check sole ownership, hard-delete the baby, and enqueue storage cleanup.

    The baby row lock (``lock_baby_profile_for_update``) is the same lock
    co-owner invite and accept take, so an owner joining or leaving cannot
    change the owner count between the check and the delete. Returns the
    outcome and, when deleted, the ``storage_cleanup_jobs`` id to publish
    after commit.
    """
    with get_connection() as conn:
        if lock_baby_profile_for_update(baby_profile_id, conn) is None:
            return SoleOwnerDeleteOutcome.NOT_OWNER, None
        membership = lock_membership_for_user_for_update(
            baby_profile_id, firebase_uid, conn
        )
        if membership is None or membership["role"] != "owner":
            return SoleOwnerDeleteOutcome.NOT_OWNER, None
        if count_active_owners(baby_profile_id, conn) > 1:
            return SoleOwnerDeleteOutcome.SHARED, None
        export_paths = collect_and_delete_export_jobs(
            conn, baby_profile_ids=[baby_profile_id]
        )
        detached = collect_photo_storage_for_babies(conn, [baby_profile_id])
        hard_delete_baby_profiles(conn, [baby_profile_id])
        job_id = insert_storage_cleanup_job(
            kind=StorageCleanupKind.BABY_PROFILE_DELETE,
            firebase_uid=firebase_uid,
            baby_profile_ids=[baby_profile_id],
            detached_objects=detached,
            export_object_paths=export_paths,
            conn=conn,
        )
        return SoleOwnerDeleteOutcome.DELETED, job_id
