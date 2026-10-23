from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.repositories.babies import update_baby_for_owner


def update_baby_profile(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any]:
    """Owner-only profile edit (``PATCH /v1/babies/{id}``, #397).

    Same gate as delete: an ended membership raises ``MEMBERSHIP_ENDED`` and any
    other non-owner (an active follower included) raises ``PermissionError``
    (HTTP 403). The owner-scoped ``UPDATE`` matching no row is the same case.
    """
    require_owner_baby(firebase_uid, baby_profile_id)
    row = update_baby_for_owner(firebase_uid, baby_profile_id, fields)
    if row is None:
        raise PermissionError("Owner access required")
    return row
