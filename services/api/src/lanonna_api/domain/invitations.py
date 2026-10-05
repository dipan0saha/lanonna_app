from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.domain.notification_copy import actor_display_name
from lanonna_api.domain.notifications import safe_enqueue_notify_user
from lanonna_api.pubsub import publish_send_invite_email
from lanonna_api.repositories.invitations import (
    accept_invitation_by_token,
    create_invitation,
    email_has_pending_invite,
    email_is_member,
    get_invitation_preview_by_token,
    list_invitations_for_baby,
    revoke_invitation,
)
from lanonna_api.repositories.memberships import list_baby_members

logger = logging.getLogger("lanonna.api.invitations")

EMAIL_QUEUE_FAILED_MESSAGE = (
    "Invitation saved; email could not be queued. "
    "Try again from Manage followers, or revoke and re-invite."
)

def list_members_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> list[dict[str, Any]]:
    require_owner_baby(firebase_uid, baby_profile_id)
    return list_baby_members(baby_profile_id)


def list_invitations_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> list[dict[str, Any]]:
    require_owner_baby(firebase_uid, baby_profile_id)
    return list_invitations_for_baby(baby_profile_id)


def revoke_invitation_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    invitation_id: uuid.UUID,
) -> None:
    require_owner_baby(firebase_uid, baby_profile_id)
    if not revoke_invitation(baby_profile_id, invitation_id):
        raise LookupError("Invitation not found")


def membership_check_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    email: str,
) -> dict[str, bool]:
    require_owner_baby(firebase_uid, baby_profile_id)
    normalized = email.strip().lower()
    return {
        "is_member": email_is_member(baby_profile_id, normalized),
        "has_pending_invite": email_has_pending_invite(baby_profile_id, normalized),
    }


class BatchInviteRow:
    __slots__ = ("email", "role", "relationship_label")

    def __init__(
        self,
        email: str,
        role: str,
        relationship_label: str | None,
    ) -> None:
        self.email = email
        self.role = role
        self.relationship_label = relationship_label


def batch_invite(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    invites: list[BatchInviteRow],
) -> list[dict[str, Any]]:
    require_owner_baby(firebase_uid, baby_profile_id)
    results: list[dict[str, Any]] = []
    for row in invites:
        email = row.email.strip().lower()
        if email_is_member(baby_profile_id, email):
            results.append(
                {
                    "email": email,
                    "status": "skipped_member",
                    "message": "Already a member",
                    "invitation_id": None,
                }
            )
            continue
        if email_has_pending_invite(baby_profile_id, email):
            results.append(
                {
                    "email": email,
                    "status": "skipped_duplicate",
                    "message": "Invitation already pending",
                    "invitation_id": None,
                }
            )
            continue
        created = create_invitation(
            baby_profile_id,
            firebase_uid,
            email,
            row.role,
            row.relationship_label,
        )
        try:
            publish_send_invite_email(created["id"], created["invite_token"])
        except Exception:
            logger.exception(
                "invite_email_enqueue_failed invitation_id=%s email=%s",
                created["id"],
                email,
            )
            results.append(
                {
                    "email": email,
                    "status": "email_queue_failed",
                    "message": EMAIL_QUEUE_FAILED_MESSAGE,
                    "invitation_id": created["id"],
                }
            )
            continue
        results.append(
            {
                "email": email,
                "status": "created",
                "message": None,
                "invitation_id": created["id"],
            }
        )
    return results


def preview_invitation(token: str) -> dict[str, Any] | None:
    return get_invitation_preview_by_token(token)


def format_preview_expires(expires_at: datetime | None) -> str | None:
    if expires_at is None:
        return None
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at.strftime("%B %d, %Y")


def accept_invitation(
    token: str,
    firebase_uid: str,
    user_email: str | None,
) -> dict[str, Any]:
    result = accept_invitation_by_token(token, firebase_uid, user_email)
    if "error" in result:
        return result
    if not result.get("already_member"):
        inviter = result.get("inviter_firebase_uid")
        baby_id = result.get("baby_profile_id")
        if inviter and baby_id:
            actor = actor_display_name(firebase_uid)
            baby_name = result.get("baby_name") or "your baby"
            safe_enqueue_notify_user(
                inviter,
                title="Invite accepted",
                body=f"{actor} joined {baby_name}",
                deep_link=f"/baby/{baby_id}/followers",
                baby_profile_id=baby_id,
            )
    return result
