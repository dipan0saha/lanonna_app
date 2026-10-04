from __future__ import annotations

import logging

from fastapi import HTTPException, status

from lanonna_api.request_context import get_request_id

logger = logging.getLogger("lanonna.api.errors")

GENERIC_INTERNAL_ERROR = "Internal server error"


def internal_error_detail() -> str:
    request_id = get_request_id()
    if request_id:
        return f"{GENERIC_INTERNAL_ERROR} (request_id={request_id})"
    return GENERIC_INTERNAL_ERROR


def map_domain_errors(exc: Exception) -> HTTPException:
    if isinstance(exc, PermissionError):
        return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc))
    if isinstance(exc, LookupError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
    if isinstance(exc, ValueError):
        return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    if isinstance(exc, RuntimeError):
        return HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )
    if isinstance(exc, HTTPException):
        return exc
    logger.exception(
        "unhandled_error request_id=%s exc_type=%s",
        get_request_id(),
        type(exc).__name__,
    )
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=internal_error_detail(),
    )
