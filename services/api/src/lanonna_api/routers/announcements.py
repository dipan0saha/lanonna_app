from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.domain import announcement as announcement_domain
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(
    prefix="/v1/babies/{baby_profile_id}/announcement",
    tags=["announcements"],
)


class AnnouncementBody(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    gender: str | None = None
    birth_date: date | None = None
    birth_time: str | None = None
    weight_text: str | None = None
    length_text: str | None = None
    photo_id: uuid.UUID | None = None


class CommentBody(BaseModel):
    body: str = Field(min_length=1)


@router.get("")
def get_announcement(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        data = announcement_domain.fetch_announcement(user["uid"], baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    if data is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return data


@router.put("")
def put_announcement(
    baby_profile_id: uuid.UUID,
    body: AnnouncementBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return announcement_domain.save_announcement(
            user["uid"],
            baby_profile_id,
            first_name=body.first_name,
            last_name=body.last_name,
            gender=body.gender,
            birth_date=body.birth_date,
            birth_time=body.birth_time,
            weight_text=body.weight_text,
            length_text=body.length_text,
            photo_id=body.photo_id,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/squish")
def post_squish(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return announcement_domain.squish_announcement(user["uid"], baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/comments")
def post_comment(
    baby_profile_id: uuid.UUID,
    body: CommentBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return announcement_domain.post_comment(user["uid"], baby_profile_id, body.body)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
