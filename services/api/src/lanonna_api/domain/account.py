from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from lanonna_api.repositories.user_engagement import (
    count_engagement_for_user,
    storage_usage_for_owner_babies,
)


def build_account_extensions(
    firebase_uid: str,
    babies: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    """Engagement and storage for My Account; ``babies`` is the caller's baby list."""
    has_owner_baby = any(b.get("role") == "owner" for b in babies)
    engagement = count_engagement_for_user(firebase_uid)
    storage_usage = storage_usage_for_owner_babies(firebase_uid) if has_owner_baby else None
    return {
        "engagement": engagement,
        "storage_usage": storage_usage,
    }
