import logging
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any, Literal, Self

from fastapi import Depends, FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware
from lanonna_api.middleware.rate_limit import RateLimitMiddleware
from lanonna_api.middleware.request_context import RequestContextMiddleware
from pydantic import BaseModel, Field, model_validator

from lanonna_api.app_check import require_app_check
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.config import settings
from lanonna_api import db
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
)
from lanonna_api.domain.errors import ErrorCode, NotFoundError, error_detail
from lanonna_api.http_errors import (
    internal_error_detail,
    map_domain_errors,
    normalize_error_detail,
)
from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.storage import (
    mint_baby_avatar_upload_url,
    mint_user_avatar_upload_url,
    warm_up_url_signer,
)

logger = logging.getLogger("lanonna.api")

# JSON bodies at least this large are gzip-compressed when the client accepts it.
GZIP_MINIMUM_SIZE = 1024


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Open the DB pool and warm the URL signer before the first request."""
    if settings.db_password:
        db.open_pool()
    try:
        warm_up_url_signer()
    except Exception:
        # No credentials (local dev) or a transient metadata error: the signer
        # retries on first use, so startup must not fail here.
        logger.warning("url_signer_warm_up_failed", exc_info=True)
    try:
        yield
    finally:
        db.close_pool()


app = FastAPI(title="La Nonna API", version="0.1.0", lifespan=lifespan)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestContextMiddleware)
_cors_origins = settings.cors_allow_origins_list()
if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
# Outermost, so every response (including errors) can be compressed.
app.add_middleware(GZipMiddleware, minimum_size=GZIP_MINIMUM_SIZE)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
    """Every HTTP error, including framework 404/405, gets a coded ``detail``."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": normalize_error_detail(exc.status_code, exc.detail)},
        headers=getattr(exc, "headers", None),
    )


@app.exception_handler(RequestValidationError)
async def request_validation_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """Body/query validation failures: ``invalid_request`` plus the field errors."""
    errors = jsonable_encoder(exc.errors())
    message = "; ".join(str(e.get("msg", "")) for e in errors if e.get("msg"))
    detail = error_detail(ErrorCode.INVALID_REQUEST, message or "Invalid request")
    detail["fields"] = errors
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": detail},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
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
    user: AppUser = Depends(current_app_user),
) -> DisplayUploadSignResponse:
    try:
        if body.scope == "baby":
            baby_id = body.baby_profile_id
            assert baby_id is not None
            if get_baby_for_owner(user.uid, baby_id) is None:
                raise NotFoundError(ErrorCode.NOT_FOUND, "Baby not found")
            signed = mint_baby_avatar_upload_url(
                baby_id,
                content_type=body.content_type,
                byte_length=body.byte_length,
            )
        else:
            signed = mint_user_avatar_upload_url(
                user.uid,
                content_type=body.content_type,
                byte_length=body.byte_length,
            )
        return DisplayUploadSignResponse(**signed)
    except (LookupError, ValueError) as exc:
        raise map_domain_errors(exc) from exc
    except Exception as exc:
        logger.exception("sign_display_upload_failed uid=%s", user.uid)
        raise map_domain_errors(RuntimeError("Signed URL generation failed")) from exc
