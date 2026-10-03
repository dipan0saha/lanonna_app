from __future__ import annotations

import logging

from fastapi import HTTPException, Request, status
from firebase_admin import app_check

from lanonna_api.auth import _ensure_firebase
from lanonna_api.config import settings

logger = logging.getLogger("lanonna.api.app_check")

_HEADER = "X-Firebase-AppCheck"


def require_app_check(request: Request) -> None:
    token = request.headers.get(_HEADER)
    if not token:
        if settings.app_check_enforce:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="App Check token required",
            )
        logger.debug("app_check_missing path=%s", request.url.path)
        return

    _ensure_firebase()
    try:
        app_check.verify_token(token)
    except Exception:
        if settings.app_check_enforce:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid App Check token",
            ) from None
        logger.warning("app_check_invalid path=%s", request.url.path)
