import logging
import uuid
from typing import Any, Literal, Self

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse
from lanonna_api.middleware.rate_limit import RateLimitMiddleware
from lanonna_api.middleware.request_context import RequestContextMiddleware
from pydantic import BaseModel, Field, model_validator

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
    members,
    notifications,
    onboarding,
    photos,
    profile,
    registry,
    search,
)
from lanonna_api.http_errors import internal_error_detail
from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.storage import mint_baby_avatar_upload_url, mint_user_avatar_upload_url

logger = logging.getLogger("lanonna.api")

app = FastAPI(title="La Nonna API", version="0.1.0")
app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestContextMiddleware)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    if isinstance(exc, HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
            headers=exc.headers,
        )
    request_id = getattr(request.state, "request_id", None)
    logger.exception(
        "unhandled_request request_id=%s path=%s",
        request_id,
        request.url.path,
    )
    headers = {}
    if request_id:
        headers["X-Request-Id"] = request_id
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": internal_error_detail()},
        headers=headers,
    )

_app_check_deps = [Depends(require_app_check)]

app.include_router(profile.router, dependencies=_app_check_deps)
app.include_router(notifications.router, dependencies=_app_check_deps)
app.include_router(onboarding.router, dependencies=_app_check_deps)
app.include_router(babies.router, dependencies=_app_check_deps)
app.include_router(invitations.router, dependencies=_app_check_deps)
app.include_router(members.router, dependencies=_app_check_deps)
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
    scope: Literal["user", "baby"] = "user"
    baby_profile_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def validate_scope(self) -> Self:
        if self.scope == "baby" and self.baby_profile_id is None:
            raise ValueError("baby_profile_id is required when scope is baby")
        if self.scope == "user" and self.baby_profile_id is not None:
            raise ValueError("baby_profile_id must be omitted when scope is user")
        return self


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
        if body.scope == "baby":
            baby_id = body.baby_profile_id
            assert baby_id is not None
            if get_baby_for_owner(user["uid"], baby_id) is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Baby not found",
                )
            signed = mint_baby_avatar_upload_url(
                baby_id,
                content_type=body.content_type,
                byte_length=body.byte_length,
            )
        else:
            signed = mint_user_avatar_upload_url(
                user["uid"],
                content_type=body.content_type,
                byte_length=body.byte_length,
            )
        return DisplayUploadSignResponse(**signed)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("sign_display_upload_failed uid=%s", user.get("uid"))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Signed URL generation failed",
        ) from exc

