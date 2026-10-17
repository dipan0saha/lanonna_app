from __future__ import annotations

from fastapi import Header, status

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.http_errors import api_error
from lanonna_api.config import settings


def require_admin_api_key(x_admin_key: str | None = Header(default=None, alias="X-Admin-Key")) -> None:
    expected = (settings.admin_api_key or "").strip()
    if not expected:
        raise api_error(status.HTTP_503_SERVICE_UNAVAILABLE, ErrorCode.SERVICE_UNAVAILABLE, "Admin API not configured")
    if not x_admin_key or x_admin_key.strip() != expected:
        raise api_error(status.HTTP_401_UNAUTHORIZED, ErrorCode.UNAUTHENTICATED, "Invalid admin key")
