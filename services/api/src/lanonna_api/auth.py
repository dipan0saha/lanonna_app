from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from lanonna_api.config import settings

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


def verify_firebase_token(id_token: str) -> dict[str, Any]:
    _ensure_firebase()
    try:
        return firebase_auth.verify_id_token(id_token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        ) from None


async def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization bearer token required",
        )
    return verify_firebase_token(credentials.credentials)
