from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from lanonna_api.app_check import require_app_check
from lanonna_api.auth import current_user
from lanonna_api.domain.invitations import (
    accept_invitation,
    format_preview_expires,
    preview_invitation,
)
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.invitations import (
    InvitationAcceptRequest,
    InvitationAcceptResponse,
    InvitationPreviewResponse,
)

router = APIRouter(prefix="/v1/invitations", tags=["invitations"])

_ACCEPT_ERROR_STATUS: dict[str, int] = {
    "not_found": status.HTTP_404_NOT_FOUND,
    "expired": status.HTTP_410_GONE,
    "revoked": status.HTTP_410_GONE,
    "email_mismatch": status.HTTP_403_FORBIDDEN,
    "max_owners": status.HTTP_409_CONFLICT,
    "already_used": status.HTTP_409_CONFLICT,
}


def _raise_invitation_accept_error(result: dict[str, Any]) -> None:
    code = result["error"]
    detail: dict[str, Any] = {"error": code}
    if code == "email_mismatch":
        detail["invitee_email"] = result.get("invitee_email")
        detail["signed_in_email"] = result.get("signed_in_email")
    raise HTTPException(
        status_code=_ACCEPT_ERROR_STATUS.get(code, status.HTTP_400_BAD_REQUEST),
        detail=detail,
    )


@router.get("/preview", response_model=InvitationPreviewResponse)
def invitation_preview(
    token: str = Query(min_length=8, max_length=256),
) -> InvitationPreviewResponse:
    preview = preview_invitation(token)
    if preview is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="not_found",
        )
    preview_status = preview.get("status")
    if preview_status in ("expired", "revoked"):
        return InvitationPreviewResponse(status=preview_status)
    expires = preview.get("expires_at")
    expires_str = (
        format_preview_expires(expires) if isinstance(expires, datetime) else None
    )
    return InvitationPreviewResponse(
        status=preview_status if preview_status in ("pending", "accepted") else "expired",
        invitation_id=preview.get("invitation_id"),
        baby_profile_id=preview.get("baby_profile_id"),
        baby_name=preview.get("baby_name"),
        inviter_display_name=preview.get("inviter_display_name"),
        invitee_email=preview.get("invitee_email"),
        relationship_label=preview.get("relationship_label"),
        invited_role=preview.get("invited_role"),
        expires_at=expires_str,
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
    user: dict[str, Any] = Depends(current_user),
) -> InvitationAcceptResponse:
    upsert_app_user(user["uid"], user.get("email"))
    result = accept_invitation(body.token, user["uid"], user.get("email"))
    if "error" in result:
        _raise_invitation_accept_error(result)
    return InvitationAcceptResponse(
        already_member=bool(result.get("already_member")),
        baby_profile_id=result.get("baby_profile_id"),
        role=result.get("role"),
        baby_name=result.get("baby_name"),
    )
