from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field

from lanonna_api.admin_auth import require_admin_api_key
from lanonna_api.repositories.system_announcements import (
    admin_create,
    admin_list_all,
    admin_soft_delete,
    admin_update,
)

router = APIRouter(
    prefix="/v1/admin/system-announcements",
    tags=["admin"],
    dependencies=[Depends(require_admin_api_key)],
)


class SystemAnnouncementCreate(BaseModel):
    title: str = Field(min_length=1)
    body: str = Field(min_length=1)
    cta_label: str | None = None
    cta_deep_link: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    target_audience: str = "all"
    priority: int = 0


class SystemAnnouncementPatch(BaseModel):
    title: str | None = None
    body: str | None = None
    cta_label: str | None = None
    cta_deep_link: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    target_audience: str | None = None
    priority: int | None = None


@router.get("")
def list_announcements() -> list[dict[str, Any]]:
    return admin_list_all()


@router.post("", status_code=status.HTTP_201_CREATED)
def create_announcement(body: SystemAnnouncementCreate) -> dict[str, Any]:
    if body.target_audience not in ("all", "owners", "followers"):
        raise HTTPException(status_code=400, detail="Invalid target_audience")
    return admin_create(
        title=body.title,
        body=body.body,
        cta_label=body.cta_label,
        cta_deep_link=body.cta_deep_link,
        starts_at=body.starts_at,
        ends_at=body.ends_at,
        target_audience=body.target_audience,
        priority=body.priority,
    )


@router.patch("/{announcement_id}")
def patch_announcement(
    announcement_id: uuid.UUID,
    body: SystemAnnouncementPatch,
) -> dict[str, Any]:
    row = admin_update(announcement_id, body.model_dump(exclude_unset=True))
    if row is None:
        raise HTTPException(status_code=404, detail="Not found")
    return row


@router.delete("/{announcement_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
def delete_announcement(announcement_id: uuid.UUID) -> Response:
    if not admin_soft_delete(announcement_id):
        raise HTTPException(status_code=404, detail="Not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
