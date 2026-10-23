from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, Query, status

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.http_errors import api_error
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.repositories.device_tokens import delete_device_token, upsert_device_token
from lanonna_api.repositories.notifications import (
    count_unread_notifications,
    list_notifications_for_user_keyset,
    mark_all_notifications_read,
    mark_notification_read,
)
from lanonna_api.repositories.system_announcements import dismiss_announcement
from lanonna_api.pagination import (
    cursor_page_from_extra_row,
    decode_created_at_id_cursor,
    encode_created_at_id_cursor,
)
from lanonna_api.schemas.device_tokens import DeviceTokenDeleteRequest, DeviceTokenUpsertRequest

router = APIRouter(prefix="/v1/me", tags=["notifications"])


@router.get("/notifications/unread-count")
def unread_notification_count(
    user: AppUser = Depends(current_app_user),
) -> dict[str, int]:
    return {"count": count_unread_notifications(user.uid)}


@router.get("/notifications")
def list_my_notifications(
    user: AppUser = Depends(current_app_user),
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
) -> dict[str, Any]:
    cursor_created_at = None
    cursor_id = None
    if cursor is not None:
        try:
            cursor_created_at, cursor_id = decode_created_at_id_cursor(cursor)
        except ValueError:
            raise api_error(
                status.HTTP_400_BAD_REQUEST,
                ErrorCode.INVALID_REQUEST,
                "Invalid cursor",
            ) from None
    rows = list_notifications_for_user_keyset(
        user.uid,
        limit=limit + 1,
        cursor_created_at=cursor_created_at,
        cursor_id=cursor_id,
    )
    page = cursor_page_from_extra_row(
        rows,
        limit=limit,
        cursor_for_row=lambda r: encode_created_at_id_cursor(
            r["created_at"], r["id"]
        ),
    )
    page["items"] = [
        {
            "id": str(r["id"]),
            "baby_profile_id": str(r["baby_profile_id"])
            if r.get("baby_profile_id")
            else None,
            # English diagnostic copy; the app renders kind + params from ARB and
            # shows these only for rows without a kind it knows.
            "title": r["title"],
            "body": r["body"],
            "deep_link": r.get("deep_link"),
            "notification_type": r.get("notification_type") or "generic",
            "notification_kind": r.get("notification_kind"),
            "params": r.get("params") or {},
            "actor_firebase_uid": r.get("actor_firebase_uid"),
            "actor_display_name": r.get("actor_display_name"),
            "read_at": r["read_at"].isoformat() if r.get("read_at") else None,
            "created_at": r["created_at"].isoformat(),
        }
        for r in page["items"]
    ]
    return page


@router.put("/device-tokens")
def register_device_token(
    body: DeviceTokenUpsertRequest,
    user: AppUser = Depends(current_app_user),
) -> dict[str, str]:
    upsert_device_token(user.uid, body.fcm_token.strip(), body.platform)
    return {"status": "ok"}


@router.delete("/device-tokens")
def unregister_device_token(
    body: DeviceTokenDeleteRequest,
    user: AppUser = Depends(current_app_user),
) -> dict[str, str]:
    delete_device_token(user.uid, body.fcm_token.strip())
    return {"status": "ok"}


@router.post("/system-announcements/{announcement_id}/dismiss")
def dismiss_system_announcement(
    announcement_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> dict[str, str]:
    if not dismiss_announcement(announcement_id, user.uid):
        raise api_error(status.HTTP_404_NOT_FOUND, ErrorCode.NOT_FOUND, "Not found")
    return {"status": "ok"}


@router.post("/notifications/read-all")
def mark_all_read(
    user: AppUser = Depends(current_app_user),
) -> dict[str, int]:
    updated = mark_all_notifications_read(user.uid)
    return {"updated": updated}


@router.patch("/notifications/{notification_id}/read")
def mark_read(
    notification_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> dict[str, str]:
    ok = mark_notification_read(notification_id, user.uid)
    if not ok:
        raise api_error(status.HTTP_404_NOT_FOUND, ErrorCode.NOT_FOUND, "Not found")
    return {"status": "ok"}
