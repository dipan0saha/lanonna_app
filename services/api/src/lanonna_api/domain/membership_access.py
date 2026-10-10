from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.repositories.babies import get_baby_membership
from lanonna_api.repositories.memberships import has_removed_membership


def require_active_membership(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    """Active baby membership or a structured error for ended access."""
    membership = get_baby_membership(firebase_uid, baby_profile_id)
    if membership is not None:
        return membership
    if has_removed_membership(baby_profile_id, firebase_uid):
        raise MemberLifecycleError(
            "membership_ended",
            "You no longer have access to this baby profile.",
        )
    raise PermissionError("Baby membership required.")
