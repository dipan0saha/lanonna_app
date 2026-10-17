from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from lanonna_api.domain.errors import ErrorCode, ServiceUnavailableError
from lanonna_api.domain.membership import require_owner_baby
from lanonna_api.domain.notification_metadata import NotificationType
from lanonna_api.domain.users_display import actor_display_name
from lanonna_api.domain.notifications import safe_enqueue_notify_user
from lanonna_api.pubsub import publish_send_invite_email
from lanonna_api.schemas.invitations import InviteRowStatus
from lanonna_api.repositories.invitations import (
    accept_invitation_by_token,
    fetch_invitation_preview_row,
    list_invitations_for_baby,
    load_invite_targets,
    prepare_invitation_for_resend,
    revoke_invitation,
    write_batch_invitations,
)
logger = logging.getLogger("lanonna.api.invitations")

EMAIL_QUEUE_FAILED_MESSAGE = (
    "Invitation saved; email could not be queued. "
    "Use Resend on Manage followers, or revoke and invite again."
)


def list_invitations_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    limit: int,
    offset: int,
) -> list[dict[str, Any]]:
    require_owner_baby(firebase_uid, baby_profile_id)
    return list_invitations_for_baby(baby_profile_id, limit=limit, offset=offset)


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
    target = load_invite_targets(baby_profile_id, [normalized]).get(normalized)
    return {
        "is_member": bool(target and target["is_member"]),
        "has_pending_invite": bool(target and target["pending_id"] is not None),
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


def _enqueue_invite_email(invitation_id: uuid.UUID) -> None:
    publish_send_invite_email(invitation_id)


def resend_invitation_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    invitation_id: uuid.UUID,
) -> None:
    require_owner_baby(firebase_uid, baby_profile_id)
    prepared_id = prepare_invitation_for_resend(baby_profile_id, invitation_id)
    if prepared_id is None:
        raise LookupError("Invitation not found")
    try:
        _enqueue_invite_email(prepared_id)
    except Exception:
        logger.exception(
            "invite_email_enqueue_failed invitation_id=%s resend=true",
            prepared_id,
        )
        raise ServiceUnavailableError(ErrorCode.EMAIL_QUEUE_FAILED, EMAIL_QUEUE_FAILED_MESSAGE) from None


def _row_result(
    email: str, status: InviteRowStatus, invitation_id: uuid.UUID | None = None
) -> dict[str, Any]:
    return {"email": email, "status": status, "invitation_id": invitation_id}


def batch_invite(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    invites: list[BatchInviteRow],
) -> list[dict[str, Any]]:
    """Invite several emails at once with one result per submitted row.

    Set-based: one read loads membership and pending-invite state for every
    email, one transaction re-arms undelivered invites and inserts the new
    ones, then each invite email is queued. A repeated email in the same
    request reports ``skipped_duplicate``.
    """
    require_owner_baby(firebase_uid, baby_profile_id)
    emails = [row.email.strip().lower() for row in invites]
    targets = load_invite_targets(baby_profile_id, emails)

    planned: list[tuple[str, InviteRowStatus | None, uuid.UUID | None]] = []
    resend_ids: list[uuid.UUID] = []
    new_invites: list[tuple[str, str, str | None]] = []
    seen: set[str] = set()
    for row, email in zip(invites, emails):
        target = targets.get(email, {})
        if email in seen:
            planned.append((email, InviteRowStatus.SKIPPED_DUPLICATE, target.get("pending_id")))
            continue
        seen.add(email)
        pending_id = target.get("pending_id")
        if target.get("is_member"):
            planned.append((email, InviteRowStatus.SKIPPED_MEMBER, None))
        elif pending_id is not None and target.get("pending_email_sent"):
            planned.append((email, InviteRowStatus.SKIPPED_DUPLICATE, pending_id))
        elif pending_id is not None:
            resend_ids.append(pending_id)
            planned.append((email, None, pending_id))
        else:
            new_invites.append((email, row.role, row.relationship_label))
            planned.append((email, None, None))

    prepared, created = write_batch_invitations(
        baby_profile_id,
        firebase_uid,
        resend_ids=resend_ids,
        new_invites=new_invites,
    )

    results: list[dict[str, Any]] = []
    for email, status, pending_id in planned:
        if status is not None:
            results.append(_row_result(email, status, pending_id))
            continue
        if pending_id is not None:
            sent_status = InviteRowStatus.RESENT
            invitation_id: uuid.UUID | None = pending_id if pending_id in prepared else None
        else:
            sent_status = InviteRowStatus.CREATED
            invitation_id = created.get(email)
        if invitation_id is None:
            # Delivered or invited by someone else between the read and the write.
            results.append(_row_result(email, InviteRowStatus.SKIPPED_DUPLICATE, pending_id))
            continue
        try:
            _enqueue_invite_email(invitation_id)
        except Exception:
            logger.exception(
                "invite_email_enqueue_failed invitation_id=%s resend=%s",
                invitation_id,
                sent_status is InviteRowStatus.RESENT,
            )
            results.append(
                _row_result(email, InviteRowStatus.EMAIL_QUEUE_FAILED, invitation_id)
            )
            continue
        results.append(_row_result(email, sent_status, invitation_id))
    return results


def _preview_payload_from_row(
    data: dict[str, Any],
    status: str,
) -> dict[str, Any]:
    return {
        "status": status,
        "invitation_id": data["id"],
        "baby_profile_id": data["baby_profile_id"],
        "baby_name": data["baby_name"],
        "inviter_display_name": data["inviter_display_name"],
        "invitee_email": data["invitee_email"],
        "relationship_label": data["relationship_label"],
        "invited_role": data["role"],
        "expires_at": data["expires_at"],
        "lifecycle_status": data["lifecycle_status"],
        "expected_birth_date": data["expected_birth_date"],
        "actual_birth_date": data["actual_birth_date"],
    }


def preview_invitation(token: str) -> dict[str, Any] | None:
    data = fetch_invitation_preview_row(token)
    if data is None:
        return None
    row_status = data["status"]
    if row_status == "revoked":
        return {"status": "revoked"}
    if row_status == "accepted":
        return _preview_payload_from_row(data, "accepted")
    if row_status != "pending":
        return {"status": "expired"}
    expires_at = data["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        return {"status": "expired"}
    return _preview_payload_from_row(data, "pending")


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
                notification_type=NotificationType.GENERIC,
                actor_firebase_uid=firebase_uid,
            )
    return result
