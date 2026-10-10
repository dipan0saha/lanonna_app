from __future__ import annotations

import logging

from fastapi import HTTPException, status

from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.user_errors import UserDeletedError
from lanonna_api.request_context import get_request_id

logger = logging.getLogger("lanonna.api.errors")

GENERIC_INTERNAL_ERROR = "Internal server error"


def internal_error_detail() -> str:
    request_id = get_request_id()
    if request_id:
        return f"{GENERIC_INTERNAL_ERROR} (request_id={request_id})"
    return GENERIC_INTERNAL_ERROR


def map_domain_errors(exc: Exception) -> HTTPException:
    if isinstance(exc, UserDeletedError):
        return HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": "user_deleted",
                "message": "This account was deleted.",
            },
        )
    if isinstance(exc, MemberLifecycleError):
        status_code = status.HTTP_400_BAD_REQUEST
        if exc.code in ("not_owner", "membership_ended"):
            status_code = status.HTTP_403_FORBIDDEN
        elif exc.code in ("target_not_member", "not_member"):
            status_code = status.HTTP_404_NOT_FOUND
        return HTTPException(
            status_code=status_code,
            detail={"error": exc.code, "message": exc.message},
        )
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
