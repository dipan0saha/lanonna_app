from __future__ import annotations

from enum import StrEnum


class PhotoPurpose(StrEnum):
    GALLERY = "gallery"
    EVENT_COVER = "event_cover"

    @classmethod
    def from_api(cls, raw: str | None) -> PhotoPurpose:
        if raw is None:
            return cls.GALLERY
        try:
            return cls(raw)
        except ValueError:
            return cls.GALLERY
