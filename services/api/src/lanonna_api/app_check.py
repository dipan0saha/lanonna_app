from __future__ import annotations

import logging

from fastapi import Request, status
from firebase_admin import app_check

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.http_errors import api_error
from lanonna_api.auth import _ensure_firebase
from lanonna_api.config import settings

logger = logging.getLogger("lanonna.api.app_check")

_HEADER = "X-Firebase-AppCheck"


def require_app_check(request: Request) -> None:
    token = request.headers.get(_HEADER)
    if not token:
        if settings.app_check_enforce:
            raise api_error(status.HTTP_401_UNAUTHORIZED, ErrorCode.APP_CHECK_FAILED, "App Check token required")
        logger.debug("app_check_missing path=%s", request.url.path)
        return

    _ensure_firebase()
    try:
        app_check.verify_token(token)
    except Exception:
        if settings.app_check_enforce:
            raise api_error(status.HTTP_401_UNAUTHORIZED, ErrorCode.APP_CHECK_FAILED, "Invalid App Check token") from None
        logger.warning("app_check_invalid path=%s", request.url.path)
