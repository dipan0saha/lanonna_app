from typing import Any

from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.config import settings
from lanonna_api.routers import (
    announcements,
    babies,
    events,
    fun,
    invitation_accept,
    invitations,
    onboarding,
    photos,
    profile,
    registry,
)
from lanonna_api.storage import mint_display_upload_url

app = FastAPI(title="La Nonna API", version="0.1.0")

app.include_router(profile.router)
app.include_router(onboarding.router)
app.include_router(babies.router)
app.include_router(invitations.router)
app.include_router(invitation_accept.router)
app.include_router(photos.router)
app.include_router(photos.baby_photos_router)
app.include_router(events.router)
app.include_router(registry.router)
app.include_router(fun.router)
app.include_router(announcements.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.get("/v1/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {
        "uid": user["uid"],
        "email": user.get("email"),
        "email_verified": user.get("email_verified", False),
    }


class DisplayUploadSignRequest(BaseModel):
    content_type: str = Field(default="image/jpeg")


class DisplayUploadSignResponse(BaseModel):
    upload_url: str
    object_path: str
    bucket: str
    content_type: str
    max_bytes: int
    expires_in_seconds: int
    required_headers: dict[str, str]


@app.post("/v1/uploads/display/signed-url", response_model=DisplayUploadSignResponse)
def sign_display_upload(
    body: DisplayUploadSignRequest,
    user: dict[str, Any] = Depends(current_user),
) -> DisplayUploadSignResponse:
    try:
        return DisplayUploadSignResponse(
            **mint_display_upload_url(user["uid"], content_type=body.content_type)
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Signed URL generation failed: {exc}",
        ) from exc

