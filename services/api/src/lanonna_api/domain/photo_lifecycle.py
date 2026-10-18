from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.photo_purpose import PhotoPurpose
from lanonna_api.repositories.events import clear_event_covers_for_photo
from lanonna_api.repositories.photos import (
    count_photo_external_references,
    delete_photo,
    get_photo_storage_row,
)
from lanonna_api.storage import delete_photo_objects_best_effort


def purge_event_cover_photo_if_unreferenced(photo_id: uuid.UUID | None) -> None:
    """Delete an event-only cover row (and GCS objects) when nothing references it."""
    if photo_id is None:
        return
    row = get_photo_storage_row(photo_id)
    if row is None:
        return
    if PhotoPurpose.from_api(row.get("purpose")) != PhotoPurpose.EVENT_COVER:
        return
    if count_photo_external_references(photo_id) > 0:
        return
    _hard_delete_photo_row(row)


def hard_delete_gallery_photo(baby_profile_id: uuid.UUID, photo_id: uuid.UUID) -> bool:
    """Clear event covers, delete the row, then drop GCS objects (best-effort)."""
    clear_event_covers_for_photo(baby_profile_id, photo_id)
    row = get_photo_storage_row(photo_id)
    if row is None or row["baby_profile_id"] != baby_profile_id:
        return False
    if not delete_photo(baby_profile_id, photo_id):
        return False
    delete_photo_objects_best_effort(
        display_path=row.get("display_path"),
        thumb_path=row.get("thumb_path"),
    )
    return True


def _hard_delete_photo_row(row: dict[str, Any]) -> None:
    baby_profile_id = row["baby_profile_id"]
    photo_id = row["id"]
    if not delete_photo(baby_profile_id, photo_id):
        return
    delete_photo_objects_best_effort(
        display_path=row.get("display_path"),
        thumb_path=row.get("thumb_path"),
    )
