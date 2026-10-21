from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.repositories.babies import get_baby_membership
from lanonna_api.repositories.memberships import membership_access_ended


def require_active_membership(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    """Active baby membership or a structured error for ended access."""
    membership = get_baby_membership(firebase_uid, baby_profile_id)
    if membership is not None:
        return membership
    if membership_access_ended(baby_profile_id, firebase_uid):
        raise MemberLifecycleError(
            ErrorCode.MEMBERSHIP_ENDED,
            "You no longer have access to this baby profile.",
        )
    raise PermissionError("Baby membership required.")
