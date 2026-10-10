from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, Response, status

from lanonna_api.auth import current_user
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.member_lifecycle import (
    leave_baby_profile,
    list_members_for_owner,
    remove_member,
)
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(prefix="/v1/babies", tags=["members"])


def _member_json(m: dict[str, Any]) -> dict[str, Any]:
    return {
        "firebase_uid": m["firebase_uid"],
        "display_name": m["display_name"],
        "email": m.get("email"),
        "role": m["role"],
        "relationship_label": m.get("relationship_label"),
        "can_remove": m.get("can_remove", False),
        "joined_at": m["created_at"].isoformat()
        if hasattr(m["created_at"], "isoformat")
        else str(m["created_at"]),
    }


@router.get("/{baby_profile_id}/members")
def list_members(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        members = list_members_for_owner(user["uid"], baby_profile_id)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    return [_member_json(m) for m in members]


@router.delete(
    "/{baby_profile_id}/members/{target_firebase_uid}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_member(
    baby_profile_id: uuid.UUID,
    target_firebase_uid: str,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        remove_member(user["uid"], baby_profile_id, target_firebase_uid)
    except (PermissionError, MemberLifecycleError) as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{baby_profile_id}/leave",
    status_code=status.HTTP_204_NO_CONTENT,
)
def leave_baby(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        leave_baby_profile(user["uid"], baby_profile_id)
    except MemberLifecycleError as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
