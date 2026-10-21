from __future__ import annotations

import uuid

from lanonna_api.db import get_connection
from lanonna_api.domain.account_delete import _safe_publish_storage_cleanup
from lanonna_api.domain.errors import ConflictError, ErrorCode
from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.repositories.account_delete_media import collect_and_delete_baby_export_jobs
from lanonna_api.repositories.baby_profile_delete import (
    SoleOwnerDeleteOutcome,
    soft_delete_baby_profile_if_sole_owner,
)
from lanonna_api.repositories.storage_cleanup_jobs import (
    create_baby_profile_storage_cleanup_job,
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
    outcome = soft_delete_baby_profile_if_sole_owner(baby_profile_id, firebase_uid)
    if outcome is SoleOwnerDeleteOutcome.SHARED:
        raise CannotDeleteSharedBabyError()
    if outcome is SoleOwnerDeleteOutcome.NOT_OWNER:
        raise PermissionError("Owner access required")
    with get_connection() as conn:
        export_paths = collect_and_delete_baby_export_jobs(conn, baby_profile_id)
    job_id = create_baby_profile_storage_cleanup_job(
        firebase_uid,
        baby_profile_id,
        export_paths,
    )
    _safe_publish_storage_cleanup(job_id)
