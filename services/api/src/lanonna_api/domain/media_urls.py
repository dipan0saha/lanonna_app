from __future__ import annotations

from lanonna_api.config import settings
from lanonna_api.storage import mint_signed_read_url


def signed_thumb_url(thumb_path: str | None) -> str | None:
    if not thumb_path:
        return None
    return mint_signed_read_url(settings.thumbnails_bucket, thumb_path)


def signed_display_url(display_path: str | None) -> str | None:
    if not display_path:
        return None
    return mint_signed_read_url(settings.display_bucket, display_path)
