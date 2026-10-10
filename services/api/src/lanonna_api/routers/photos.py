from __future__ import annotations

import uuid
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.domain import gallery as gallery_domain
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(tags=["photos"])


class PhotoInitRequest(BaseModel):
    baby_profile_id: uuid.UUID
    content_type: str = Field(default="image/jpeg")
    byte_length: int = Field(gt=0, le=2_097_152)
    caption: str | None = Field(default=None, max_length=2000)


class CaptionPatch(BaseModel):
    caption: str | None = None


class CommentBody(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class CommentPatch(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class PhotoTagsBody(BaseModel):
    tagged_baby_profile_ids: list[uuid.UUID] = Field(default_factory=list)


@router.post("/v1/photos/init")
def photos_init(
    body: PhotoInitRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        caption = body.caption.strip() if body.caption else None
        if caption == "":
            caption = None
        result = gallery_domain.init_photo_upload(
            user,
            body.baby_profile_id,
            body.content_type,
            body.byte_length,
            caption=caption,
        )
        return {
            "photo_id": result["photo_id"],
            "upload_url": result["upload_url"],
            "object_path": result["object_path"],
            "content_type": result["content_type"],
            "max_bytes": result["max_bytes"],
            "required_headers": result["required_headers"],
            "expires_in_seconds": result["expires_in_seconds"],
        }
    except Exception as exc:
        raise map_domain_errors(exc) from exc


baby_photos_router = APIRouter(
    prefix="/v1/babies/{baby_profile_id}/photos",
    tags=["photos"],
)


@baby_photos_router.get("")
def list_photos(
    baby_profile_id: uuid.UUID,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    sort: Literal["default", "recent", "favorites"] = Query(default="default"),
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return gallery_domain.list_gallery(
            user["uid"], baby_profile_id, limit, offset, sort=sort
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.get("/{photo_id}")
def photo_detail(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return gallery_domain.get_photo_detail(user["uid"], baby_profile_id, photo_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.patch("/{photo_id}")
def patch_photo(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    body: CaptionPatch,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return gallery_domain.patch_caption(
            user["uid"], baby_profile_id, photo_id, body.caption
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.delete("/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_photo_route(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        gallery_domain.remove_photo(user["uid"], baby_profile_id, photo_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@baby_photos_router.post("/{photo_id}/squish")
def squish(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return gallery_domain.squish_photo(user["uid"], baby_profile_id, photo_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.patch("/{photo_id}/comments/{comment_id}")
def patch_comment(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: CommentPatch,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return gallery_domain.edit_comment(
            user["uid"], baby_profile_id, photo_id, comment_id, body.body
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.put("/{photo_id}/tags")
def put_photo_tags(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    body: PhotoTagsBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return gallery_domain.set_photo_baby_tags(
            user["uid"],
            baby_profile_id,
            photo_id,
            body.tagged_baby_profile_ids,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.post("/{photo_id}/comments")
def create_comment(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    body: CommentBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return gallery_domain.add_comment(
            user["uid"], baby_profile_id, photo_id, body.body
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@baby_photos_router.delete(
    "/{photo_id}/comments/{comment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_comment_route(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        gallery_domain.delete_comment(
            user["uid"], baby_profile_id, photo_id, comment_id
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
