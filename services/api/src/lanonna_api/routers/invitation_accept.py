from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status

from lanonna_api.app_check import require_app_check
from lanonna_api.domain.errors import ErrorCode
from lanonna_api.http_errors import api_error, map_domain_errors
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.invitations import (
    accept_invitation,
    preview_invitation,
)
from lanonna_api.schemas.invitations import (
    InvitationAcceptRequest,
    InvitationAcceptResponse,
    InvitationPreviewResponse,
)

router = APIRouter(prefix="/v1/invitations", tags=["invitations"])


@router.get("/preview", response_model=InvitationPreviewResponse)
def invitation_preview(
    token: str = Query(min_length=8, max_length=256),
) -> InvitationPreviewResponse:
    preview = preview_invitation(token)
    if preview is None:
        raise api_error(
            status.HTTP_404_NOT_FOUND, ErrorCode.NOT_FOUND, "Invitation not found"
        )
    preview_status = preview.get("status")
    if preview_status in ("expired", "revoked"):
        return InvitationPreviewResponse(status=preview_status)
    return InvitationPreviewResponse(
        status=preview_status if preview_status in ("pending", "accepted") else "expired",
        invitation_id=preview.get("invitation_id"),
        baby_profile_id=preview.get("baby_profile_id"),
        baby_name=preview.get("baby_name"),
        inviter_display_name=preview.get("inviter_display_name"),
        invitee_email=preview.get("invitee_email"),
        relationship_label=preview.get("relationship_label"),
        invited_role=preview.get("invited_role"),
        expires_at=preview.get("expires_at"),
        lifecycle_status=preview.get("lifecycle_status"),
        expected_birth_date=preview.get("expected_birth_date"),
        actual_birth_date=preview.get("actual_birth_date"),
    )


@router.post(
    "/accept",
    response_model=InvitationAcceptResponse,
    dependencies=[Depends(require_app_check)],
)
def invitation_accept(
    body: InvitationAcceptRequest,
    user: AppUser = Depends(current_app_user),
) -> InvitationAcceptResponse:
    try:
        result = accept_invitation(body.token, user.uid, user.email)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return InvitationAcceptResponse(
        already_member=bool(result.get("already_member")),
        baby_profile_id=result.get("baby_profile_id"),
        role=result.get("role"),
        baby_name=result.get("baby_name"),
    )
