from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from lanonna_api.auth import current_user
from lanonna_api.repositories.babies import get_baby_for_owner
from lanonna_api.pubsub import publish_send_invite_email
from lanonna_api.repositories.invitations import (
    create_invitation,
    email_has_pending_invite,
    email_is_member,
    list_invitations_for_baby,
    revoke_invitation,
)
from lanonna_api.repositories.memberships import list_baby_members
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.invitations import (
    BatchInviteRequest,
    BatchInviteResponse,
    InviteRowResult,
    MembershipCheckResponse,
)

router = APIRouter(prefix="/v1/babies", tags=["invitations"])


@router.get("/{baby_profile_id}/members")
def list_members(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    if get_baby_for_owner(user["uid"], baby_profile_id) is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner access required")
    members = list_baby_members(baby_profile_id)
    return [
        {
            "firebase_uid": m["firebase_uid"],
            "display_name": m["display_name"],
            "email": m.get("email"),
            "role": m["role"],
            "relationship_label": m.get("relationship_label"),
            "joined_at": m["created_at"].isoformat()
            if hasattr(m["created_at"], "isoformat")
            else str(m["created_at"]),
        }
        for m in members
    ]


@router.get("/{baby_profile_id}/invitations")
def list_invitations(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    if get_baby_for_owner(user["uid"], baby_profile_id) is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner access required")
    rows = list_invitations_for_baby(baby_profile_id)
    return [
        {
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
        for r in rows
    ]


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
    if get_baby_for_owner(user["uid"], baby_profile_id) is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner access required")
    if not revoke_invitation(baby_profile_id, invitation_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invitation not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{baby_profile_id}/membership-check", response_model=MembershipCheckResponse)
def membership_check(
    baby_profile_id: uuid.UUID,
    email: str = Query(min_length=3),
    user: dict[str, Any] = Depends(current_user),
) -> MembershipCheckResponse:
    upsert_app_user(user["uid"], user.get("email"))
    if get_baby_for_owner(user["uid"], baby_profile_id) is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner access required")
    normalized = email.strip().lower()
    return MembershipCheckResponse(
        is_member=email_is_member(baby_profile_id, normalized),
        has_pending_invite=email_has_pending_invite(baby_profile_id, normalized),
    )


@router.post("/{baby_profile_id}/invitations/batch", response_model=BatchInviteResponse)
def batch_invite(
    baby_profile_id: uuid.UUID,
    body: BatchInviteRequest,
    user: dict[str, Any] = Depends(current_user),
) -> BatchInviteResponse:
    upsert_app_user(user["uid"], user.get("email"))
    if get_baby_for_owner(user["uid"], baby_profile_id) is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner access required")

    results: list[InviteRowResult] = []
    for row in body.invites:
        email = row.email.strip().lower()
        if email_is_member(baby_profile_id, email):
            results.append(
                InviteRowResult(
                    email=email,
                    status="skipped_member",
                    message="Already a member",
                )
            )
            continue
        if email_has_pending_invite(baby_profile_id, email):
            results.append(
                InviteRowResult(
                    email=email,
                    status="skipped_duplicate",
                    message="Invitation already pending",
                )
            )
            continue
        created = create_invitation(
            baby_profile_id,
            user["uid"],
            email,
            row.role,
            row.relationship_label,
        )
        try:
            publish_send_invite_email(created["id"], created["invite_token"])
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Invitation saved but email could not be queued: {exc}",
            ) from exc
        results.append(
            InviteRowResult(
                email=email,
                status="created",
                invitation_id=created["id"],
            )
        )

    return BatchInviteResponse(results=results)
