from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain import announcement as announcement_domain
from lanonna_api.http_errors import api_error, map_domain_errors

router = APIRouter(
    prefix="/v1/babies/{baby_profile_id}/announcement",
    tags=["announcements"],
)


class AnnouncementBody(BaseModel):
    first_name: str | None = Field(default=None, max_length=50)
    last_name: str | None = Field(default=None, max_length=50)
    gender: str | None = None
    birth_date: date | None = None
    birth_time: str | None = None
    weight_text: str | None = Field(default=None, max_length=40)
    length_text: str | None = Field(default=None, max_length=40)
    photo_id: uuid.UUID | None = None


class CommentBody(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


@router.get("")
def get_announcement(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        data = announcement_domain.fetch_announcement(user.uid, baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    if data is None:
        raise api_error(status.HTTP_404_NOT_FOUND, ErrorCode.NOT_FOUND, "Not found")
    return data


@router.put("")
def put_announcement(
    baby_profile_id: uuid.UUID,
    body: AnnouncementBody,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        fields = body.model_dump(exclude_unset=True)
        return announcement_domain.patch_announcement(
            user.uid,
            baby_profile_id,
            fields,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.patch("")
def patch_announcement_route(
    baby_profile_id: uuid.UUID,
    body: AnnouncementBody,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        fields = body.model_dump(exclude_unset=True)
        return announcement_domain.patch_announcement(
            user.uid,
            baby_profile_id,
            fields,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/squish")
def post_squish(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        return announcement_domain.squish_announcement(user.uid, baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/comments")
def post_comment(
    baby_profile_id: uuid.UUID,
    body: CommentBody,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        return announcement_domain.post_comment(user.uid, baby_profile_id, body.body)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
