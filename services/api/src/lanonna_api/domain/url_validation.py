"""Normalize and validate optional user-entered http(s) URLs (registry, calendar)."""

from __future__ import annotations

from urllib.parse import urlparse

INVALID_HTTP_URL = "Enter a valid link, e.g. https://…"
_MAX_URL_LENGTH = 2048


def normalize_optional_http_url(raw: str | None) -> str | None:
    """Return normalized https URL, None if empty, or raise ValueError."""
    if raw is None:
        return None
    value = raw.strip()
    if not value:
        return None
    if len(value) > _MAX_URL_LENGTH:
        raise ValueError(INVALID_HTTP_URL)
    if " " in value:
        raise ValueError(INVALID_HTTP_URL)

    if "://" not in value:
        value = f"https://{value}"

    parsed = urlparse(value)
    if parsed.scheme not in ("http", "https"):
        raise ValueError(INVALID_HTTP_URL)

    host = parsed.netloc
    if not host:
        raise ValueError(INVALID_HTTP_URL)
    if host != "localhost" and "." not in host:
        raise ValueError(INVALID_HTTP_URL)

    return value
