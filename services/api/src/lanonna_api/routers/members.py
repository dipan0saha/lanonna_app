from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, Query, Response, status

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.pagination import offset_page_from_extra_row
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.member_lifecycle import (
    leave_baby_profile,
    list_members_for_owner,
    remove_member,
)
from lanonna_api.http_errors import map_domain_errors

router = APIRouter(prefix="/v1/babies", tags=["members"])


def _member_json(m: dict[str, Any]) -> dict[str, Any]:
    return {
        "firebase_uid": m["firebase_uid"],
        "display_name": m["display_name"],
        "role": m["role"],
        "can_remove": m.get("can_remove", False),
        "joined_at": m["created_at"].isoformat()
        if hasattr(m["created_at"], "isoformat")
        else str(m["created_at"]),
    }


@router.get("/{baby_profile_id}/members")
def list_members(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    try:
        members = list_members_for_owner(
            user.uid, baby_profile_id, limit=limit + 1, offset=offset
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return offset_page_from_extra_row(
        [_member_json(m) for m in members], offset=offset, limit=limit
    )


@router.delete(
    "/{baby_profile_id}/members/{target_firebase_uid}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_member(
    baby_profile_id: uuid.UUID,
    target_firebase_uid: str,
    user: AppUser = Depends(current_app_user),
) -> Response:
    try:
        remove_member(user.uid, baby_profile_id, target_firebase_uid)
    except (PermissionError, MemberLifecycleError) as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{baby_profile_id}/leave",
    status_code=status.HTTP_204_NO_CONTENT,
)
def leave_baby(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> Response:
    try:
        leave_baby_profile(user.uid, baby_profile_id)
    except MemberLifecycleError as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
