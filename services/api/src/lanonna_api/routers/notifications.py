from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from lanonna_api.auth import current_user
from lanonna_api.repositories.device_tokens import delete_device_token, upsert_device_token
from lanonna_api.repositories.notifications import (
    count_unread_notifications,
    list_notifications_for_user,
    mark_notification_read,
)
from lanonna_api.repositories.system_announcements import dismiss_announcement
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.device_tokens import DeviceTokenDeleteRequest, DeviceTokenUpsertRequest

router = APIRouter(prefix="/v1/me", tags=["notifications"])


@router.get("/notifications/unread-count")
def unread_notification_count(
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, int]:
    upsert_app_user(user["uid"], user.get("email"))
    return {"count": count_unread_notifications(user["uid"])}


@router.get("/notifications")
def list_my_notifications(
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    rows = list_notifications_for_user(user["uid"], limit=50)
    return [
        {
            "id": str(r["id"]),
            "baby_profile_id": str(r["baby_profile_id"])
            if r.get("baby_profile_id")
            else None,
            "title": r["title"],
            "body": r["body"],
            "deep_link": r.get("deep_link"),
            "read_at": r["read_at"].isoformat() if r.get("read_at") else None,
            "created_at": r["created_at"].isoformat(),
        }
        for r in rows
    ]


@router.put("/device-tokens")
def register_device_token(
    body: DeviceTokenUpsertRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, str]:
    upsert_app_user(user["uid"], user.get("email"))
    upsert_device_token(user["uid"], body.fcm_token.strip(), body.platform)
    return {"status": "ok"}


@router.delete("/device-tokens")
def unregister_device_token(
    body: DeviceTokenDeleteRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, str]:
    delete_device_token(user["uid"], body.fcm_token.strip())
    return {"status": "ok"}


@router.post("/system-announcements/{announcement_id}/dismiss")
def dismiss_system_announcement(
    announcement_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, str]:
    upsert_app_user(user["uid"], user.get("email"))
    if not dismiss_announcement(announcement_id, user["uid"]):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return {"status": "ok"}


@router.patch("/notifications/{notification_id}/read")
def mark_read(
    notification_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, str]:
    ok = mark_notification_read(notification_id, user["uid"])
    if not ok:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return {"status": "ok"}
