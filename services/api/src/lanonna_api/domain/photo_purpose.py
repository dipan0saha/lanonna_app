from __future__ import annotations

from enum import StrEnum


class PhotoPurpose(StrEnum):
    """``photos.purpose``: gallery share vs event-only cover (#315)."""

    GALLERY = "gallery"
    EVENT_COVER = "event_cover"
