from __future__ import annotations

from collections.abc import Sequence
from typing import Any
import uuid

from lanonna_api.domain.media_urls import signed_display_urls
from lanonna_api.domain.storage_references import (
    avatar_object_path_authorized,
    display_object_path_from_client_value,
    normalize_owned_avatar_for_storage,
)


def gcs_object_path_from_stored(stored: str) -> str | None:
    """Resolve a display-bucket object path from DB value or legacy public GCS URL."""
    return display_object_path_from_client_value(stored)


def normalize_user_avatar_for_storage(value: str | None, firebase_uid: str) -> str | None:
    return normalize_owned_avatar_for_storage(
        value, owner_kind="user", owner_id=firebase_uid
    )


def normalize_baby_avatar_for_storage(
    value: str | None, baby_profile_id: uuid.UUID
) -> str | None:
    return normalize_owned_avatar_for_storage(
        value, owner_kind="baby", owner_id=str(baby_profile_id)
    )


def signed_user_avatar_url(stored: str | None, firebase_uid: str) -> str | None:
    return signed_avatar_urls_for_owners(
        [(stored, "user", firebase_uid)],
    )[0]


def signed_baby_avatar_urls_from_rows(rows: Sequence[dict[str, Any]]) -> list[str | None]:
    owners: list[tuple[str | None, str, str]] = []
    for row in rows:
        owners.append(
            (row.get("avatar_url"), "baby", str(row["id"])),
        )
    return signed_avatar_urls_for_owners(owners)


def signed_avatar_urls_for_owners(
    entries: Sequence[tuple[str | None, str, str]],
) -> list[str | None]:
    """Sign bucket avatars only when the stored path matches the row owner."""
    paths: list[str | None] = []
    for stored, owner_kind, owner_id in entries:
        paths.append(
            avatar_object_path_authorized(
                stored,
                owner_kind=owner_kind,  # type: ignore[arg-type]
                owner_id=owner_id,
            )
        )
    return signed_display_urls(paths)


def signed_avatar_urls(stored_values: Sequence[str | None]) -> list[str | None]:
    """Legacy batch sign without ownership — signs any avatars/ path (tests only)."""
    paths: list[str | None] = []
    for stored in stored_values:
        s = (stored or "").strip()
        path = display_object_path_from_client_value(s) if s else None
        if path is not None and path.startswith("avatars/"):
            paths.append(path)
        else:
            paths.append(None)
    return signed_display_urls(paths)


def signed_avatar_url(stored: str | None) -> str | None:
    """Sign without ownership check — prefer signed_user_avatar_url at call sites."""
    return signed_avatar_urls([stored])[0]
