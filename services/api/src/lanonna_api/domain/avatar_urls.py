from __future__ import annotations

from collections.abc import Sequence
from urllib.parse import unquote, urlparse

from lanonna_api.config import settings
from lanonna_api.domain.media_urls import signed_display_urls

_BUCKET_OBJECT_PREFIXES = ("avatars/", "smoke/")


def gcs_object_path_from_stored(stored: str) -> str | None:
    """Resolve a display-bucket object path from DB value or legacy public GCS URL."""
    s = stored.strip()
    if not s:
        return None
    if s.startswith(_BUCKET_OBJECT_PREFIXES):
        return s

    if not (s.startswith("http://") or s.startswith("https://")):
        return None

    bucket = settings.display_bucket
    parsed = urlparse(s)
    path = unquote(parsed.path.lstrip("/"))

    if parsed.netloc == "storage.googleapis.com":
        if path.startswith(f"{bucket}/"):
            return path[len(bucket) + 1 :]
        parts = path.split("/", 1)
        if len(parts) == 2 and parts[0] == bucket:
            return parts[1]

    if parsed.netloc == f"{bucket}.storage.googleapis.com":
        return path

    return None


def normalize_avatar_for_storage(value: str | None) -> str | None:
    """Persist object paths (not signed URLs). Allow external HTTPS (e.g. OAuth)."""
    if value is None:
        return None
    s = value.strip()
    if not s:
        return None

    path = gcs_object_path_from_stored(s)
    if path is not None:
        if not path.startswith(_BUCKET_OBJECT_PREFIXES):
            raise ValueError("Avatar object path must be under avatars/ or smoke/")
        return path

    if s.startswith("http://") or s.startswith("https://"):
        return s

    raise ValueError("avatar_url must be a GCS object path or HTTPS URL")


def signed_avatar_urls(stored_values: Sequence[str | None]) -> list[str | None]:
    """Read URLs for stored avatars, bucket objects signed as one batch.

    Bucket paths (and legacy public GCS URLs) get a short-lived signed URL;
    external HTTPS URLs (e.g. OAuth) pass through; anything else is ``None``.
    """
    paths: list[str | None] = []
    passthrough: list[str | None] = []
    for stored in stored_values:
        s = (stored or "").strip()
        path = gcs_object_path_from_stored(s) if s else None
        paths.append(path)
        if path is None and (s.startswith("http://") or s.startswith("https://")):
            passthrough.append(s)
        else:
            passthrough.append(None)
    signed = signed_display_urls(paths)
    return [url if url is not None else ext for url, ext in zip(signed, passthrough)]


def signed_avatar_url(stored: str | None) -> str | None:
    """Short-lived read URL for bucket avatars; pass through external HTTPS URLs."""
    return signed_avatar_urls([stored])[0]
