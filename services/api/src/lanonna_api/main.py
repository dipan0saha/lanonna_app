import logging
from typing import Any

from fastapi import Depends, FastAPI, HTTPException, status
from lanonna_api.middleware.rate_limit import RateLimitMiddleware
from lanonna_api.middleware.request_context import RequestContextMiddleware
from pydantic import BaseModel, Field

from lanonna_api.app_check import require_app_check
from lanonna_api.auth import current_user
from lanonna_api.config import settings
from lanonna_api.routers import (
    admin_system_announcements,
    announcements,
    app_config,
    babies,
    data_export,
    events,
    fun,
    invitation_accept,
    invitations,
    notifications,
    onboarding,
    photos,
    profile,
    registry,
    search,
)
from lanonna_api.storage import mint_display_upload_url

logger = logging.getLogger("lanonna.api")

app = FastAPI(title="La Nonna API", version="0.1.0")
app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestContextMiddleware)

_app_check_deps = [Depends(require_app_check)]

app.include_router(profile.router, dependencies=_app_check_deps)
app.include_router(notifications.router, dependencies=_app_check_deps)
app.include_router(onboarding.router, dependencies=_app_check_deps)
app.include_router(babies.router, dependencies=_app_check_deps)
app.include_router(invitations.router, dependencies=_app_check_deps)
app.include_router(invitation_accept.router)
app.include_router(app_config.router)
app.include_router(photos.router, dependencies=_app_check_deps)
app.include_router(photos.baby_photos_router, dependencies=_app_check_deps)
app.include_router(events.router, dependencies=_app_check_deps)
app.include_router(registry.router, dependencies=_app_check_deps)
app.include_router(fun.router, dependencies=_app_check_deps)
app.include_router(announcements.router, dependencies=_app_check_deps)
app.include_router(search.router, dependencies=_app_check_deps)
app.include_router(data_export.router, dependencies=_app_check_deps)
app.include_router(admin_system_announcements.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


class DisplayUploadSignRequest(BaseModel):
    content_type: str = Field(default="image/jpeg")
    byte_length: int = Field(gt=0, le=2_097_152)


class DisplayUploadSignResponse(BaseModel):
    upload_url: str
    object_path: str
    bucket: str
    content_type: str
    max_bytes: int
    expires_in_seconds: int
    required_headers: dict[str, str]


@app.post(
    "/v1/uploads/display/signed-url",
    response_model=DisplayUploadSignResponse,
    dependencies=_app_check_deps,
)
def sign_display_upload(
    body: DisplayUploadSignRequest,
    user: dict[str, Any] = Depends(current_user),
) -> DisplayUploadSignResponse:
    try:
        return DisplayUploadSignResponse(
            **mint_display_upload_url(
                user["uid"],
                content_type=body.content_type,
                byte_length=body.byte_length,
            )
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("sign_display_upload_failed uid=%s", user.get("uid"))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Signed URL generation failed",
        ) from exc

