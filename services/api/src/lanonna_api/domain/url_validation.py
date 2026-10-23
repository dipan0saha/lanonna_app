"""Normalize and validate optional user-entered links (registry, calendar).

Links are opened by every member, so they must be ``https`` on a real host in
every environment (#415). A bare domain gets ``https://``.
"""

from __future__ import annotations

from urllib.parse import urlparse
from lanonna_api.domain.errors import ErrorCode, InvalidInputError

INVALID_HTTP_URL = "Enter a secure link that starts with https://"
_MAX_URL_LENGTH = 2048


def normalize_optional_http_url(raw: str | None) -> str | None:
    """Return normalized https URL, None if empty, or raise ValueError."""
    if raw is None:
        return None
    value = raw.strip()
    if not value:
        return None
    if len(value) > _MAX_URL_LENGTH:
        raise InvalidInputError(ErrorCode.INVALID_URL, INVALID_HTTP_URL)
    if " " in value:
        raise InvalidInputError(ErrorCode.INVALID_URL, INVALID_HTTP_URL)

    if "://" not in value:
        value = f"https://{value}"

    parsed = urlparse(value)
    if parsed.scheme != "https":
        raise InvalidInputError(ErrorCode.INVALID_URL, INVALID_HTTP_URL)
    try:
        parsed.port
    except ValueError:
        raise InvalidInputError(ErrorCode.INVALID_URL, INVALID_HTTP_URL) from None
    if not parsed.hostname or "." not in parsed.hostname:
        raise InvalidInputError(ErrorCode.INVALID_URL, INVALID_HTTP_URL)

    return value
