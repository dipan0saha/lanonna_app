from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.http_errors import api_error
from lanonna_api.config import settings
from lanonna_api.domain.user_errors import UserDeletedError
from lanonna_api.repositories.users import resolve_app_user

_bearer = HTTPBearer(auto_error=False)
_app_initialized = False


def _ensure_firebase() -> None:
    global _app_initialized
    if _app_initialized:
        return
    firebase_admin.initialize_app(
        options={"projectId": settings.gcp_project_id},
    )
    _app_initialized = True


def _token_audience(claims: dict[str, Any]) -> str | None:
    aud = claims.get("aud")
    if isinstance(aud, str) and aud:
        return aud
    if isinstance(aud, list) and aud:
        first = aud[0]
        return str(first) if first else None
    return None


def verify_firebase_token(id_token: str) -> dict[str, Any]:
    _ensure_firebase()
    try:
        claims = firebase_auth.verify_id_token(id_token)
    except Exception:
        raise api_error(status.HTTP_401_UNAUTHORIZED, ErrorCode.UNAUTHENTICATED, "Invalid or expired Firebase ID token") from None
    allowed = settings.firebase_audience_allowlist()
    token_aud = _token_audience(claims)
    if token_aud is None or token_aud not in allowed:
        raise api_error(status.HTTP_401_UNAUTHORIZED, ErrorCode.UNAUTHENTICATED, "Invalid or expired Firebase ID token")
    return claims


def _user_deleted_http() -> HTTPException:
    error = UserDeletedError()
    return HTTPException(status_code=error.status_code, detail=error.detail())


@dataclass(frozen=True)
class AppUser:
    """Request-scoped app user resolved once per authenticated request."""

    uid: str
    email: str | None
    display_name: str | None
    claims: MappingProxyType
    row: dict[str, Any] = field(default_factory=dict)


async def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    """Verify the Firebase ID token. Does not read or write ``app_users``.

    Account deletion retry (``POST /v1/me/delete-account``) uses this directly
    so a tombstoned row can finish Firebase deletion. Every other authenticated
    route depends on ``current_app_user``.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise api_error(status.HTTP_401_UNAUTHORIZED, ErrorCode.UNAUTHENTICATED, "Authorization bearer token required")
    return verify_firebase_token(credentials.credentials)


def current_app_user(claims: dict[str, Any] = Depends(current_user)) -> AppUser:
    """Resolve the app user once per request and reject tombstoned accounts."""
    try:
        row = resolve_app_user(claims["uid"], claims.get("email"))
    except UserDeletedError:
        raise _user_deleted_http() from None
    return AppUser(
        uid=str(row["firebase_uid"]),
        email=row.get("email"),
        display_name=row.get("display_name"),
        claims=MappingProxyType(dict(claims)),
        row=dict(row),
    )
