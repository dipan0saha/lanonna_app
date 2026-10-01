from __future__ import annotations

import uuid
from typing import Literal

from datetime import date

from pydantic import BaseModel, EmailStr, Field


class InviteRowRequest(BaseModel):
    email: EmailStr
    role: Literal["owner", "follower"] = "follower"
    relationship_label: str | None = Field(default=None, max_length=80)


class BatchInviteRequest(BaseModel):
    invites: list[InviteRowRequest] = Field(default_factory=list, max_length=20)


class InviteRowResult(BaseModel):
    email: str
    status: Literal["created", "skipped_member", "skipped_invalid", "skipped_duplicate"]
    invitation_id: uuid.UUID | None = None
    message: str | None = None


class BatchInviteResponse(BaseModel):
    results: list[InviteRowResult]


class MembershipCheckResponse(BaseModel):
    is_member: bool
    has_pending_invite: bool


class InvitationPreviewResponse(BaseModel):
    status: Literal["pending", "expired"]
    invitation_id: uuid.UUID | None = None
    baby_profile_id: uuid.UUID | None = None
    baby_name: str | None = None
    inviter_display_name: str | None = None
    invitee_email: str | None = None
    relationship_label: str | None = None
    invited_role: Literal["owner", "follower"] | None = None
    expires_at: str | None = None
    lifecycle_status: Literal["expecting", "born"] | None = None
    expected_birth_date: date | None = None
    actual_birth_date: date | None = None


class InvitationAcceptRequest(BaseModel):
    token: str = Field(min_length=8, max_length=256)


class InvitationAcceptResponse(BaseModel):
    already_member: bool = False
    baby_profile_id: uuid.UUID | None = None
    role: Literal["owner", "follower"] | None = None
    baby_name: str | None = None
    error: Literal[
        "not_found",
        "expired",
        "email_mismatch",
        "max_owners",
    ] | None = None
    invitee_email: str | None = None
    signed_in_email: str | None = None
