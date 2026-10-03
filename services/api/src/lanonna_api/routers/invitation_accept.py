from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from lanonna_api.app_check import require_app_check
from lanonna_api.auth import current_user
from lanonna_api.domain.notification_copy import actor_display_name
from lanonna_api.domain.notifications import enqueue_notify_user
from lanonna_api.repositories.invitations import (
    accept_invitation_by_token,
    get_invitation_preview_by_token,
)
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.invitations import (
    InvitationAcceptRequest,
    InvitationAcceptResponse,
    InvitationPreviewResponse,
)

router = APIRouter(prefix="/v1/invitations", tags=["invitations"])


def _format_expires(expires_at: datetime | None) -> str | None:
    if expires_at is None:
        return None
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at.strftime("%B %d, %Y")


@router.get("/preview", response_model=InvitationPreviewResponse)
def invitation_preview(
    token: str = Query(min_length=8, max_length=256),
) -> InvitationPreviewResponse:
    preview = get_invitation_preview_by_token(token)
    if preview is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="not_found",
        )
    if preview.get("status") == "expired":
        return InvitationPreviewResponse(status="expired")
    expires = preview.get("expires_at")
    expires_str = _format_expires(expires) if isinstance(expires, datetime) else None
    return InvitationPreviewResponse(
        status="pending",
        invitation_id=preview["invitation_id"],
        baby_profile_id=preview["baby_profile_id"],
        baby_name=preview["baby_name"],
        inviter_display_name=preview["inviter_display_name"],
        invitee_email=preview["invitee_email"],
        relationship_label=preview.get("relationship_label"),
        invited_role=preview["invited_role"],
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
    result = accept_invitation_by_token(
        body.token,
        user["uid"],
        user.get("email"),
    )
    if "error" in result:
        return InvitationAcceptResponse(
            error=result["error"],
            invitee_email=result.get("invitee_email"),
            signed_in_email=result.get("signed_in_email"),
        )
    if not result.get("already_member"):
        inviter = result.get("inviter_firebase_uid")
        baby_id = result.get("baby_profile_id")
        if inviter and baby_id:
            actor = actor_display_name(user["uid"])
            baby_name = result.get("baby_name") or "your baby"
            enqueue_notify_user(
                inviter,
                title="Invite accepted",
                body=f"{actor} joined {baby_name}",
                deep_link=f"/baby/{baby_id}/followers",
                baby_profile_id=baby_id,
            )
    return InvitationAcceptResponse(
        already_member=bool(result.get("already_member")),
        baby_profile_id=result.get("baby_profile_id"),
        role=result.get("role"),
        baby_name=result.get("baby_name"),
    )
