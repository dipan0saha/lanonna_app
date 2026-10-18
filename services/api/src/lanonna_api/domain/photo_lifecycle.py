"""Photo row + storage deletion shared by gallery delete and cover cleanup (#315)."""

from __future__ import annotations

import uuid
from typing import Any

from lanonna_api import storage
from lanonna_api.repositories.photos import (
    delete_gallery_photo_row,
    delete_unreferenced_event_cover,
)


def purge_event_cover_photo_if_unreferenced(photo_id: uuid.UUID | None) -> None:
    """After a cover is replaced/removed or its event deleted, drop the photo if
    it is an ``event_cover`` nothing else uses. Gallery photos are never purged."""
    if photo_id is None:
        return
    _delete_objects(delete_unreferenced_event_cover(photo_id))


def delete_gallery_photo(baby_profile_id: uuid.UUID, photo_id: uuid.UUID) -> bool:
    """Delete a gallery photo (events using it as cover lose the cover)."""
    deleted = delete_gallery_photo_row(baby_profile_id, photo_id)
    _delete_objects(deleted)
    return deleted is not None


def _delete_objects(deleted: dict[str, Any] | None) -> None:
    if deleted is None:
        return
    storage.delete_photo_objects_best_effort(
        display_path=deleted.get("display_path"),
        thumb_path=deleted.get("thumb_path"),
    )
