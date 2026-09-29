import uuid
from typing import Any

from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.config import settings
from lanonna_api.db import upsert_app_user
from lanonna_api.domain import assert_owner_membership, create_pending_photo
from lanonna_api.storage import mint_display_upload_for_object, mint_display_upload_url

app = FastAPI(title="La Nonna API", version="0.1.0")


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


@app.get("/v1/profile")
def profile(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    row = upsert_app_user(user["uid"], user.get("email"))
    return {
        "firebase_uid": row["firebase_uid"],
        "email": row["email"],
        "created_at": row["created_at"].isoformat(),
        "updated_at": row["updated_at"].isoformat(),
    }


class DisplayUploadSignRequest(BaseModel):
    content_type: str = Field(default="image/jpeg")


@app.post("/v1/uploads/display/signed-url")
def sign_display_upload(
    body: DisplayUploadSignRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, str | int]:
    try:
        return mint_display_upload_url(user["uid"], content_type=body.content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Signed URL generation failed: {exc}",
        ) from exc


class PhotoInitRequest(BaseModel):
    baby_profile_id: uuid.UUID
    content_type: str = Field(default="image/jpeg")
    byte_length: int = Field(gt=0)


@app.post("/v1/photos/init")
def photos_init(
    body: PhotoInitRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    max_bytes = 2_097_152
    if body.byte_length > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Display asset exceeds maximum size.",
        )
    upsert_app_user(user["uid"], user.get("email"))
    try:
        assert_owner_membership(user["uid"], body.baby_profile_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc

    try:
        photo = create_pending_photo(
            body.baby_profile_id,
            user["uid"],
            body.content_type,
            body.byte_length,
        )
        signed = mint_display_upload_for_object(
            photo["display_path"],
            content_type=body.content_type,
            max_bytes=max_bytes,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Photo init failed: {exc}",
        ) from exc

    return {
        "photo_id": str(photo["id"]),
        "upload_url": signed["upload_url"],
        "object_path": signed["object_path"],
        "content_type": signed["content_type"],
        "max_bytes": signed["max_bytes"],
        "required_headers": signed["required_headers"],
        "expires_in_seconds": signed["expires_in_seconds"],
    }
