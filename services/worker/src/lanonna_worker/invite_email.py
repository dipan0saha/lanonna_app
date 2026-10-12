from __future__ import annotations

import logging
import random
import time
import uuid
from enum import Enum
from html import escape
from datetime import datetime, timezone
from typing import Any
from pathlib import Path
from urllib.parse import quote

import httpx

from lanonna_worker.config import mailjet_sender_error, settings
from lanonna_worker.db import get_connection
from lanonna_worker.invite_email_copy import (
    invite_email_intro_html,
    invite_email_intro_text,
    invite_email_subject,
)

logger = logging.getLogger("lanonna.worker.invite_email")

_TEMPLATE_DIR = Path(__file__).resolve().parents[2] / "email_templates"

_CLAIM_STALE_MINUTES = 15
_MAILJET_IN_PROCESS_RETRIES = 3
_ERROR_MAX_LEN = 500


class InviteSendOutcome(str, Enum):
    SENT = "sent"
    SKIPPED = "skipped"
    RETRY = "retry"
    FAILED = "failed"


def _load_template(name: str) -> str:
    path = _TEMPLATE_DIR / name
    return path.read_text(encoding="utf-8")


def _format_expires(expires_at: datetime) -> str:
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at.astimezone(timezone.utc).strftime("%B %d, %Y")


def build_invite_url(
    invite_token: str,
    invited_role: str,
    *,
    base: str | None = None,
) -> str:
    """HTTPS invite landing URL. The token is a query param and must not be logged."""
    origin = (base if base is not None else settings.invite_deep_link_base).strip().rstrip("/")
    role_param = "&role=owner" if invited_role == "owner" else ""
    token = quote(invite_token, safe="")
    if origin.startswith("https://"):
        return f"{origin}/invite?token={token}{role_param}"
    return f"{origin}/invite-accept?token={token}{role_param}"


def _claim_invitation_for_send(
    conn: Any,
    invitation_id: uuid.UUID,
) -> dict | None:
    claimed = conn.execute(
        """
        UPDATE invitations
        SET email_send_claimed_at = now(),
            email_send_attempts = email_send_attempts + 1,
            updated_at = now()
        WHERE id = %s
          AND status = 'pending'
          AND email_sent_at IS NULL
          AND (
            email_send_claimed_at IS NULL
            OR email_send_claimed_at < now() - make_interval(mins => %s)
          )
        RETURNING id
        """,
        (invitation_id, _CLAIM_STALE_MINUTES),
    ).fetchone()
    if claimed is None:
        return None
    row = conn.execute(
        """
        SELECT
            i.invitee_email,
            i.role,
            i.relationship_label,
            i.expires_at,
            i.email_invite_token,
            b.name AS baby_name,
            COALESCE(u.display_name, 'A family member') AS inviter_display_name
        FROM invitations i
        JOIN baby_profiles b ON b.id = i.baby_profile_id AND b.deleted_at IS NULL
        JOIN app_users u ON u.firebase_uid = i.inviter_firebase_uid
        WHERE i.id = %s
        """,
        (invitation_id,),
    ).fetchone()
    if row is None:
        _release_invite_send_claim(conn, invitation_id)
        return None
    return dict(row)


def _release_invite_send_claim(conn: Any, invitation_id: uuid.UUID) -> None:
    conn.execute(
        """
        UPDATE invitations
        SET email_send_claimed_at = NULL,
            updated_at = now()
        WHERE id = %s
          AND email_sent_at IS NULL
        """,
        (invitation_id,),
    )


def _mark_invite_email_sent(conn: Any, invitation_id: uuid.UUID) -> bool:
    row = conn.execute(
        """
        UPDATE invitations
        SET email_sent_at = now(),
            email_delivery_status = 'sent',
            email_last_error = NULL,
            email_send_claimed_at = NULL,
            email_invite_token = NULL,
            updated_at = now()
        WHERE id = %s
          AND email_sent_at IS NULL
          AND status = 'pending'
        RETURNING id
        """,
        (invitation_id,),
    ).fetchone()
    return row is not None


def _mark_invite_email_failed(
    conn: Any,
    invitation_id: uuid.UUID,
    error: str,
) -> None:
    trimmed = error.strip()[:_ERROR_MAX_LEN]
    conn.execute(
        """
        UPDATE invitations
        SET email_delivery_status = 'failed',
            email_last_error = %s,
            email_send_claimed_at = NULL,
            updated_at = now()
        WHERE id = %s
          AND email_sent_at IS NULL
          AND status = 'pending'
        """,
        (trimmed, invitation_id),
    )


def _record_transient_error(conn: Any, invitation_id: uuid.UUID, error: str) -> None:
    trimmed = error.strip()[:_ERROR_MAX_LEN]
    conn.execute(
        """
        UPDATE invitations
        SET email_last_error = %s,
            updated_at = now()
        WHERE id = %s
          AND email_sent_at IS NULL
          AND status = 'pending'
        """,
        (trimmed, invitation_id),
    )


def _render_invite_email(ctx: dict, invite_url: str) -> tuple[str, str, str]:
    inviter = ctx["inviter_display_name"]
    baby = ctx["baby_name"]
    role = ctx.get("role") or "follower"
    invitee = ctx["invitee_email"]
    expires = _format_expires(ctx["expires_at"])
    relationship = ctx.get("relationship_label")
    relationship_line = (
        f"You're listed as: {relationship}." if relationship else ""
    )
    relationship_block = (
        f'<p style="margin:0 0 20px;font-size:15px;color:#6b5b57;">Relationship: {escape(relationship)}</p>'
        if relationship
        else ""
    )

    html = _load_template("invite_v1.html")
    text = _load_template("invite_v1.txt")
    replacements = {
        "{{invite_url}}": invite_url,
        "{{invitee_email}}": escape(invitee),
        "{{expires_at}}": expires,
        "{{relationship_block}}": relationship_block,
        "{{relationship_line}}": relationship_line,
        "{{invite_intro_text}}": invite_email_intro_text(inviter, baby, role),
        "{{invite_intro_html}}": invite_email_intro_html(inviter, baby, role),
    }
    for key, value in replacements.items():
        html = html.replace(key, value)
        text = text.replace(key, value)

    subject = invite_email_subject(inviter, baby, role)
    return subject, html, text


def _mailjet_message_error(response: httpx.Response) -> str | None:
    """Mailjet can return HTTP 200 with Messages[0].Status == error (#43)."""
    try:
        body = response.json()
    except Exception:
        return "Mailjet response was not JSON"
    messages = body.get("Messages") if isinstance(body, dict) else None
    if not isinstance(messages, list) or not messages or not isinstance(messages[0], dict):
        return "Mailjet response missing Messages"
    status = messages[0].get("Status")
    if status == "success":
        return None
    codes: list[str] = []
    errors = messages[0].get("Errors") or []
    if isinstance(errors, list):
        for err in errors:
            if isinstance(err, dict) and err.get("ErrorCode"):
                codes.append(str(err["ErrorCode"]))
    code = ",".join(codes) if codes else "unknown"
    return f"Mailjet message status={status} error_code={code}"


def _is_transient_http_status(status_code: int) -> bool:
    return status_code == 429 or status_code >= 500


def _is_transient_exception(exc: BaseException) -> bool:
    return isinstance(
        exc,
        (
            httpx.ConnectError,
            httpx.ReadTimeout,
            httpx.WriteTimeout,
            httpx.ConnectTimeout,
            httpx.PoolTimeout,
            httpx.NetworkError,
        ),
    )


def _post_mailjet(payload: dict[str, Any]) -> httpx.Response:
    last_exc: BaseException | None = None
    for attempt in range(1, _MAILJET_IN_PROCESS_RETRIES + 1):
        try:
            response = httpx.post(
                "https://api.mailjet.com/v3.1/send",
                auth=(settings.mailjet_api_key, settings.mailjet_api_secret),
                json=payload,
                timeout=30.0,
            )
        except Exception as exc:
            last_exc = exc
            if not _is_transient_exception(exc) or attempt >= _MAILJET_IN_PROCESS_RETRIES:
                raise
            time.sleep(random.uniform(0.2, 0.8) * attempt)
            continue
        if _is_transient_http_status(response.status_code):
            if attempt >= _MAILJET_IN_PROCESS_RETRIES:
                return response
            time.sleep(random.uniform(0.2, 0.8) * attempt)
            continue
        return response
    if last_exc is not None:
        raise last_exc
    raise RuntimeError("Mailjet send failed without response")


def send_invite_email(
    invitation_id: uuid.UUID,
    *,
    delivery_attempt: int | None = None,
    final_attempt: bool = False,
) -> InviteSendOutcome:
    if not settings.mailjet_api_key or not settings.mailjet_api_secret:
        logger.error(
            "mailjet_not_configured invitation_id=%s",
            invitation_id,
        )
        with get_connection() as conn:
            _mark_invite_email_failed(
                conn,
                invitation_id,
                "Mailjet is not configured; cannot send invite email",
            )
        return InviteSendOutcome.FAILED

    sender_error = mailjet_sender_error(settings.mailjet_from_email)
    if sender_error:
        logger.error(
            "mailjet_sender_rejected invitation_id=%s reason=%s",
            invitation_id,
            sender_error,
        )
        with get_connection() as conn:
            _mark_invite_email_failed(conn, invitation_id, sender_error)
        return InviteSendOutcome.FAILED

    with get_connection() as conn:
        ctx = _claim_invitation_for_send(conn, invitation_id)
    if ctx is None:
        logger.info(
            "invite_email_skip invitation_id=%s not claimable",
            invitation_id,
        )
        return InviteSendOutcome.SKIPPED

    invite_token = ctx.get("email_invite_token")
    if not invite_token:
        logger.warning(
            "invite_email_skip invitation_id=%s missing delivery token",
            invitation_id,
        )
        with get_connection() as conn:
            _mark_invite_email_failed(
                conn,
                invitation_id,
                "Invite email delivery token missing",
            )
        return InviteSendOutcome.FAILED

    invite_url = build_invite_url(str(invite_token), ctx["role"])
    subject, html, text = _render_invite_email(ctx, invite_url)

    payload = {
        "Messages": [
            {
                "From": {
                    "Email": settings.mailjet_from_email,
                    "Name": settings.mailjet_from_name,
                },
                "To": [{"Email": ctx["invitee_email"]}],
                "Subject": subject,
                "HTMLPart": html,
                "TextPart": text,
            }
        ]
    }

    try:
        response = _post_mailjet(payload)
    except Exception as exc:
        transient = _is_transient_exception(exc)
        message = f"{type(exc).__name__}: {exc}"
        logger.error(
            "mailjet_send_failed invitation_id=%s transient=%s error=%s",
            invitation_id,
            transient,
            message,
        )
        with get_connection() as conn:
            if transient and not final_attempt:
                _record_transient_error(conn, invitation_id, message)
                _release_invite_send_claim(conn, invitation_id)
                return InviteSendOutcome.RETRY
            _mark_invite_email_failed(conn, invitation_id, message)
        return InviteSendOutcome.FAILED

    if response.status_code >= 300:
        transient = _is_transient_http_status(response.status_code)
        message = f"Mailjet HTTP {response.status_code}"
        logger.error(
            "mailjet_send_failed invitation_id=%s status=%s body=%s",
            invitation_id,
            response.status_code,
            response.text[:500],
        )
        with get_connection() as conn:
            if transient and not final_attempt:
                _record_transient_error(conn, invitation_id, message)
                _release_invite_send_claim(conn, invitation_id)
                return InviteSendOutcome.RETRY
            _mark_invite_email_failed(conn, invitation_id, message)
        return InviteSendOutcome.FAILED

    message_error = _mailjet_message_error(response)
    if message_error:
        logger.error(
            "mailjet_send_failed invitation_id=%s %s",
            invitation_id,
            message_error,
        )
        with get_connection() as conn:
            _mark_invite_email_failed(conn, invitation_id, message_error)
        return InviteSendOutcome.FAILED

    with get_connection() as conn:
        if not _mark_invite_email_sent(conn, invitation_id):
            logger.info(
                "invite_email_skip_already_sent invitation_id=%s",
                invitation_id,
            )
            return InviteSendOutcome.SKIPPED

    logger.info(
        "invite_email_sent invitation_id=%s delivery_attempt=%s",
        invitation_id,
        delivery_attempt,
    )
    return InviteSendOutcome.SENT
