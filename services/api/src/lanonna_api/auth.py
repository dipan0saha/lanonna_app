from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from lanonna_api.config import settings
from lanonna_api.domain.auth_session import UserDeletedError, assert_active_user

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
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        ) from None
    allowed = settings.firebase_audience_allowlist()
    token_aud = _token_audience(claims)
    if token_aud is None or token_aud not in allowed:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        )
    return claims


async def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization bearer token required",
        )
    claims = verify_firebase_token(credentials.credentials)
    try:
        assert_active_user(claims["uid"])
    except UserDeletedError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": "user_deleted",
                "message": "This account was deleted.",
            },
        ) from None
    return claims
