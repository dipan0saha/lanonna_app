from __future__ import annotations

import uuid

from lanonna_api.domain.errors import ConflictError, ErrorCode
from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.repositories.baby_profile_delete import soft_delete_baby_profiles
from lanonna_api.repositories.memberships import count_active_owners


class CannotDeleteSharedBabyError(ConflictError):
    def __init__(self) -> None:
        super().__init__(
            ErrorCode.CANNOT_DELETE_SHARED_BABY,
            "This baby profile has a co-owner. Leave the profile instead of "
            "deleting it.",
        )


def delete_baby_profile(firebase_uid: str, baby_profile_id: uuid.UUID) -> None:
    """Soft-delete a baby profile when the caller is the only active owner."""
    require_owner_baby(firebase_uid, baby_profile_id)
    if count_active_owners(baby_profile_id) > 1:
        raise CannotDeleteSharedBabyError()
    soft_delete_baby_profiles([baby_profile_id])
