from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, Query, Response, status

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.invitations import (
    BatchInviteRow,
    batch_invite,
    list_invitations_for_owner,
    membership_check_for_owner,
    resend_invitation_for_owner,
    revoke_invitation_for_owner,
)
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.pagination import offset_page_from_extra_row
from lanonna_api.input_limits import MAX_MEMBERSHIP_CHECK_EMAIL_LEN
from lanonna_api.schemas.invitations import (
    BatchInviteRequest,
    BatchInviteResponse,
    InviteRowResult,
    MembershipCheckResponse,
)

router = APIRouter(prefix="/v1/babies", tags=["invitations"])


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
        "email_delivery_status": r.get("email_delivery_status"),
        "email_last_error": r.get("email_last_error"),
        "email_send_attempts": r.get("email_send_attempts"),
    }


@router.get("/{baby_profile_id}/invitations")
def list_invitations(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    try:
        rows = list_invitations_for_owner(user.uid, baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    window = rows[offset : offset + limit + 1]
    page = offset_page_from_extra_row(
        [_invitation_json(r) for r in window],
        offset=offset,
        limit=limit,
    )
    return page


@router.post(
    "/{baby_profile_id}/invitations/{invitation_id}/resend",
    status_code=status.HTTP_204_NO_CONTENT,
)
def resend_invitation(
    baby_profile_id: uuid.UUID,
    invitation_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> Response:
    try:
        resend_invitation_for_owner(user.uid, baby_profile_id, invitation_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{baby_profile_id}/invitations/{invitation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_invitation(
    baby_profile_id: uuid.UUID,
    invitation_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> Response:
    try:
        revoke_invitation_for_owner(user.uid, baby_profile_id, invitation_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{baby_profile_id}/membership-check", response_model=MembershipCheckResponse)
def membership_check(
    baby_profile_id: uuid.UUID,
    email: str = Query(min_length=3, max_length=MAX_MEMBERSHIP_CHECK_EMAIL_LEN),
    user: AppUser = Depends(current_app_user),
) -> MembershipCheckResponse:
    try:
        result = membership_check_for_owner(user.uid, baby_profile_id, email)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return MembershipCheckResponse(**result)


@router.post("/{baby_profile_id}/invitations/batch", response_model=BatchInviteResponse)
def batch_invite_route(
    baby_profile_id: uuid.UUID,
    body: BatchInviteRequest,
    user: AppUser = Depends(current_app_user),
) -> BatchInviteResponse:
    invite_rows = [
        BatchInviteRow(
            email=row.email,
            role=row.role,
            relationship_label=row.relationship_label,
        )
        for row in body.invites
    ]
    try:
        results = batch_invite(user.uid, baby_profile_id, invite_rows)
    except Exception as exc:
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
