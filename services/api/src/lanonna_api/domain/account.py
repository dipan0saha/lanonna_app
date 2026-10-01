from __future__ import annotations

from typing import Any

from lanonna_api.repositories.babies import list_babies_for_user
from lanonna_api.repositories.user_engagement import (
    count_engagement_for_user,
    storage_usage_for_owner_babies,
)


def build_account_extensions(firebase_uid: str) -> dict[str, Any]:
    babies = list_babies_for_user(firebase_uid)
    has_owner_baby = any(b.get("role") == "owner" for b in babies)
    engagement = count_engagement_for_user(firebase_uid)
    storage_usage = storage_usage_for_owner_babies(firebase_uid) if has_owner_baby else None
    return {
        "engagement": engagement,
        "storage_usage": storage_usage,
    }
