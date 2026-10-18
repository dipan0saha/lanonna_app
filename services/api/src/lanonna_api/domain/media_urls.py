"""Signed read URLs for photo assets, signed as one batch per response.

Build every URL a response needs with one call (``sign_media`` or the list
helpers) instead of one call per row: the shared signer serves cached URLs
for free and signs the misses in parallel (``storage.GcsUrlSigner``).
"""

from __future__ import annotations

from collections.abc import Sequence
from typing import Literal

from lanonna_api.config import settings
from lanonna_api.storage import mint_signed_read_urls

MediaKind = Literal["thumb", "display"]


def _bucket(kind: MediaKind) -> str:
    return settings.thumbnails_bucket if kind == "thumb" else settings.display_bucket


def sign_media(refs: Sequence[tuple[MediaKind, str | None]]) -> list[str | None]:
    """Signed URLs in input order; ``None`` for a missing path."""
    wanted = [(i, _bucket(kind), path) for i, (kind, path) in enumerate(refs) if path]
    urls: list[str | None] = [None] * len(refs)
    if wanted:
        signed = mint_signed_read_urls([(bucket, path) for _, bucket, path in wanted])
        for (i, _, _), url in zip(wanted, signed):
            urls[i] = url
    return urls


def signed_thumb_urls(thumb_paths: Sequence[str | None]) -> list[str | None]:
    return sign_media([("thumb", path) for path in thumb_paths])


def signed_display_urls(display_paths: Sequence[str | None]) -> list[str | None]:
    return sign_media([("display", path) for path in display_paths])


def signed_thumb_url(thumb_path: str | None) -> str | None:
    return signed_thumb_urls([thumb_path])[0]


def signed_display_url(display_path: str | None) -> str | None:
    return signed_display_urls([display_path])[0]
