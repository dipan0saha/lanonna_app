from __future__ import annotations

import uuid
from enum import StrEnum
from typing import Literal

from datetime import date, datetime

from pydantic import BaseModel, EmailStr, Field


class InviteRowRequest(BaseModel):
    email: EmailStr
    role: Literal["owner", "follower"] = "follower"
    relationship_label: str | None = Field(default=None, max_length=80)


class BatchInviteRequest(BaseModel):
    invites: list[InviteRowRequest] = Field(default_factory=list, max_length=20)


class InviteRowStatus(StrEnum):
    """Outcome of one batch-invite row; the app keys its copy off these values."""

    CREATED = "created"
    RESENT = "resent"
    SKIPPED_MEMBER = "skipped_member"
    SKIPPED_DUPLICATE = "skipped_duplicate"
    SKIPPED_MAX_OWNERS = "skipped_max_owners"
    EMAIL_QUEUE_FAILED = "email_queue_failed"


class InviteRowResult(BaseModel):
    email: str
    status: InviteRowStatus
    invitation_id: uuid.UUID | None = None


class BatchInviteResponse(BaseModel):
    results: list[InviteRowResult]


class MembershipCheckResponse(BaseModel):
    is_member: bool
    has_pending_invite: bool


class InvitationPreviewResponse(BaseModel):
    status: Literal["pending", "expired", "accepted", "revoked"]
    invitation_id: uuid.UUID | None = None
    baby_profile_id: uuid.UUID | None = None
    baby_name: str | None = None
    inviter_display_name: str | None = None
    invitee_email: str | None = None
    relationship_label: str | None = None
    invited_role: Literal["owner", "follower"] | None = None
    expires_at: datetime | None = None
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
