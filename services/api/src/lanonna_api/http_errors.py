"""Domain errors → HTTP, in one place.

Every error response carries ``detail = {"error": <ErrorCode>, "message": ...}``
(see ``domain/errors.py``). The app keys localized copy off ``error``; the
English ``message`` is diagnostic only.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import HTTPException, status

from lanonna_api.domain.errors import DomainError, ErrorCode, error_detail
from lanonna_api.request_context import get_request_id

logger = logging.getLogger("lanonna.api.errors")

GENERIC_INTERNAL_ERROR = "Internal server error"

# Generic code for a status when nothing more specific was raised (bare
# builtins, framework 404/405/422, plain-string HTTPExceptions).
_CODE_BY_STATUS: dict[int, ErrorCode] = {
    status.HTTP_400_BAD_REQUEST: ErrorCode.INVALID_REQUEST,
    status.HTTP_401_UNAUTHORIZED: ErrorCode.UNAUTHENTICATED,
    status.HTTP_403_FORBIDDEN: ErrorCode.FORBIDDEN,
    status.HTTP_404_NOT_FOUND: ErrorCode.NOT_FOUND,
    status.HTTP_405_METHOD_NOT_ALLOWED: ErrorCode.NOT_FOUND,
    status.HTTP_409_CONFLICT: ErrorCode.CONFLICT,
    status.HTTP_422_UNPROCESSABLE_ENTITY: ErrorCode.INVALID_REQUEST,
    status.HTTP_429_TOO_MANY_REQUESTS: ErrorCode.RATE_LIMITED,
    status.HTTP_503_SERVICE_UNAVAILABLE: ErrorCode.SERVICE_UNAVAILABLE,
}


def code_for_status(status_code: int) -> ErrorCode:
    if status_code in _CODE_BY_STATUS:
        return _CODE_BY_STATUS[status_code]
    if status_code >= 500:
        return ErrorCode.INTERNAL_ERROR
    return ErrorCode.INVALID_REQUEST


def internal_error_detail() -> dict[str, Any]:
    request_id = get_request_id()
    message = (
        f"{GENERIC_INTERNAL_ERROR} (request_id={request_id})"
        if request_id
        else GENERIC_INTERNAL_ERROR
    )
    return error_detail(ErrorCode.INTERNAL_ERROR, message)


def api_error(
    status_code: int,
    code: ErrorCode,
    message: str,
    *,
    headers: dict[str, str] | None = None,
) -> HTTPException:
    """An ``HTTPException`` with the standard coded ``detail``.

    For checks that live in routers or dependencies rather than domain code.
    """
    return HTTPException(
        status_code=status_code,
        detail=error_detail(code, message),
        headers=headers,
    )


def normalize_error_detail(status_code: int, detail: Any) -> dict[str, Any]:
    """Coerce any ``HTTPException.detail`` into the coded shape (safety net)."""
    if isinstance(detail, dict) and isinstance(detail.get("error"), str):
        if "message" not in detail:
            return {**detail, "message": detail["error"]}
        return detail
    message = detail if isinstance(detail, str) and detail else str(detail or "")
    return error_detail(code_for_status(status_code), message or "Request failed")


def map_domain_errors(exc: Exception) -> HTTPException:
    if isinstance(exc, HTTPException):
        return exc
    if isinstance(exc, DomainError):
        return HTTPException(status_code=exc.status_code, detail=exc.detail())
    for builtin, status_code in (
        (PermissionError, status.HTTP_403_FORBIDDEN),
        (LookupError, status.HTTP_404_NOT_FOUND),
        (ValueError, status.HTTP_400_BAD_REQUEST),
        (RuntimeError, status.HTTP_503_SERVICE_UNAVAILABLE),
    ):
        if isinstance(exc, builtin):
            return HTTPException(
                status_code=status_code,
                detail=error_detail(code_for_status(status_code), str(exc)),
            )
    logger.exception(
        "unhandled_error request_id=%s exc_type=%s",
        get_request_id(),
        type(exc).__name__,
    )
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=internal_error_detail(),
    )
