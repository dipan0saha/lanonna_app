"""Avatar writes and reads (#415): only owned display-bucket objects.

Writes persist the owned object path (``storage_references``). Reads sign a
stored path only when it still sits under the row owner's prefix, so a legacy
row naming someone else's object or an outside URL reads as no avatar.
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from typing import Any

from lanonna_api.domain.media_urls import signed_display_urls
from lanonna_api.domain.storage_references import (
    baby_avatar_prefix,
    normalize_avatar_for_storage,
    owned_avatar_path,
    user_avatar_prefix,
)


def normalize_user_avatar_for_storage(value: str | None, firebase_uid: str) -> str | None:
    return normalize_avatar_for_storage(value, user_avatar_prefix(firebase_uid))


def normalize_baby_avatar_for_storage(
    value: str | None, baby_profile_id: uuid.UUID
) -> str | None:
    return normalize_avatar_for_storage(value, baby_avatar_prefix(baby_profile_id))


def signed_user_avatar_url(stored: str | None, firebase_uid: str) -> str | None:
    return signed_display_urls([owned_avatar_path(stored, user_avatar_prefix(firebase_uid))])[0]


def signed_baby_avatar_urls(rows: Sequence[dict[str, Any]]) -> list[str | None]:
    """One signing batch for baby rows (``id``, ``avatar_url``)."""
    return signed_display_urls(
        [
            owned_avatar_path(row.get("avatar_url"), baby_avatar_prefix(row["id"]))
            for row in rows
        ]
    )
