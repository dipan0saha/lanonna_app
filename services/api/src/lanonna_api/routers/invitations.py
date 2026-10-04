from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from lanonna_api.auth import current_user
from lanonna_api.domain.invitations import (
    BatchInviteRow,
    batch_invite,
    list_invitations_for_owner,
    list_members_for_owner,
    membership_check_for_owner,
    revoke_invitation_for_owner,
)
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.invitations import (
    BatchInviteRequest,
    BatchInviteResponse,
    InviteRowResult,
    MembershipCheckResponse,
)

router = APIRouter(prefix="/v1/babies", tags=["invitations"])


def _member_json(m: dict[str, Any]) -> dict[str, Any]:
    return {
        "firebase_uid": m["firebase_uid"],
        "display_name": m["display_name"],
        "email": m.get("email"),
        "role": m["role"],
        "relationship_label": m.get("relationship_label"),
        "joined_at": m["created_at"].isoformat()
        if hasattr(m["created_at"], "isoformat")
        else str(m["created_at"]),
    }


def _invitation_json(r: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": r["id"],
        "invitee_email": r["invitee_email"],
        "role": r["role"],
        "relationship_label": r.get("relationship_label"),
        "status": r["status"],
        "expires_at": r["expires_at"].isoformat()
        if hasattr(r["expires_at"], "isoformat")
        else str(r["expires_at"]),
        "created_at": r["created_at"].isoformat()
        if hasattr(r["created_at"], "isoformat")
        else str(r["created_at"]),
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


@router.get("/{baby_profile_id}/invitations")
def list_invitations(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        rows = list_invitations_for_owner(user["uid"], baby_profile_id)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    return [_invitation_json(r) for r in rows]


@router.delete(
    "/{baby_profile_id}/invitations/{invitation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_invitation(
    baby_profile_id: uuid.UUID,
    invitation_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        revoke_invitation_for_owner(user["uid"], baby_profile_id, invitation_id)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    except LookupError as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{baby_profile_id}/membership-check", response_model=MembershipCheckResponse)
def membership_check(
    baby_profile_id: uuid.UUID,
    email: str = Query(min_length=3),
    user: dict[str, Any] = Depends(current_user),
) -> MembershipCheckResponse:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        result = membership_check_for_owner(user["uid"], baby_profile_id, email)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    return MembershipCheckResponse(**result)


@router.post("/{baby_profile_id}/invitations/batch", response_model=BatchInviteResponse)
def batch_invite_route(
    baby_profile_id: uuid.UUID,
    body: BatchInviteRequest,
    user: dict[str, Any] = Depends(current_user),
) -> BatchInviteResponse:
    upsert_app_user(user["uid"], user.get("email"))
    invite_rows = [
        BatchInviteRow(
            email=row.email,
            role=row.role,
            relationship_label=row.relationship_label,
        )
        for row in body.invites
    ]
    try:
        results = batch_invite(user["uid"], baby_profile_id, invite_rows)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    except RuntimeError as exc:
        raise map_domain_errors(exc) from exc
    return BatchInviteResponse(
        results=[
            InviteRowResult(
                email=r["email"],
                status=r["status"],
                message=r.get("message"),
                invitation_id=r.get("invitation_id"),
            )
            for r in results
        ]
    )
