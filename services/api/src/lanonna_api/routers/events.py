from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain import calendar as calendar_domain
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(prefix="/v1/babies/{baby_profile_id}/events", tags=["events"])


class EventCreate(BaseModel):
    title: str = Field(min_length=1)
    starts_at: datetime
    ends_at: datetime | None = None
    description: str | None = None
    location: str | None = None
    video_call_url: str | None = None
    cover_photo_id: uuid.UUID | None = None


class EventUpdate(BaseModel):
    title: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    description: str | None = None
    location: str | None = None
    video_call_url: str | None = None
    cover_photo_id: uuid.UUID | None = None


class RsvpBody(BaseModel):
    status: str = Field(pattern="^(going|maybe|cant_go)$")


class CommentBody(BaseModel):
    body: str = Field(min_length=1)


@router.get("")
def list_events_route(
    baby_profile_id: uuid.UUID,
    month: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    upcoming: bool = Query(default=False),
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return calendar_domain.list_calendar_events(
            user["uid"], baby_profile_id, month=month, upcoming=upcoming
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("", status_code=status.HTTP_201_CREATED)
def create_event_route(
    baby_profile_id: uuid.UUID,
    body: EventCreate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return calendar_domain.create_calendar_event(
            user["uid"],
            baby_profile_id,
            title=body.title,
            starts_at=body.starts_at,
            ends_at=body.ends_at,
            description=body.description,
            location=body.location,
            video_call_url=body.video_call_url,
            cover_photo_id=body.cover_photo_id,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.get("/{event_id}")
def event_detail(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return calendar_domain.get_event_detail(user["uid"], baby_profile_id, event_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.patch("/{event_id}")
def patch_event(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    body: EventUpdate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    fields = body.model_dump(exclude_unset=True)
    try:
        return calendar_domain.update_calendar_event(
            user["uid"], baby_profile_id, event_id, fields
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event_route(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        calendar_domain.remove_calendar_event(user["uid"], baby_profile_id, event_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put("/{event_id}/rsvp")
def rsvp_route(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    body: RsvpBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return calendar_domain.set_rsvp(
            user["uid"], baby_profile_id, event_id, body.status
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/{event_id}/comments")
def create_event_comment(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    body: CommentBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return calendar_domain.add_event_comment(
            user["uid"], baby_profile_id, event_id, body.body
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.patch("/{event_id}/comments/{comment_id}")
def patch_event_comment(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: CommentBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return calendar_domain.edit_event_comment(
            user["uid"], baby_profile_id, event_id, comment_id, body.body
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.delete(
    "/{event_id}/comments/{comment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_event_comment_route(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        calendar_domain.delete_event_comment(
            user["uid"], baby_profile_id, event_id, comment_id
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
