from __future__ import annotations

import uuid

from lanonna_api.domain.errors import ConflictError, ErrorCode
from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.domain.storage_cleanup import enqueue_storage_cleanup
from lanonna_api.repositories.baby_profile_delete import (
    SoleOwnerDeleteOutcome,
    soft_delete_baby_profile_if_sole_owner,
)


class CannotDeleteSharedBabyError(ConflictError):
    def __init__(self) -> None:
        super().__init__(
            ErrorCode.CANNOT_DELETE_SHARED_BABY,
            "This baby profile has a co-owner. Leave the profile instead of "
            "deleting it.",
        )


def delete_baby_profile(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    """Soft-delete a baby profile when the caller is the only active owner (FR-BABY-007)."""
    require_owner_baby(firebase_uid, baby_profile_id)
    outcome, cleanup_job_id = soft_delete_baby_profile_if_sole_owner(
        baby_profile_id, firebase_uid
    )
    if outcome is SoleOwnerDeleteOutcome.SHARED:
        raise CannotDeleteSharedBabyError()
    if outcome is SoleOwnerDeleteOutcome.NOT_OWNER:
        raise PermissionError("Owner access required")
    if cleanup_job_id is not None:
        enqueue_storage_cleanup(cleanup_job_id)
