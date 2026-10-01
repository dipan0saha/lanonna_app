from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

import httpx
import psycopg
from psycopg.rows import dict_row

from lanonna_worker.config import settings

logger = logging.getLogger("lanonna.worker.invite_email")

_TEMPLATE_DIR = Path(__file__).resolve().parents[2] / "email_templates"


def _connection() -> psycopg.Connection:
    if not settings.db_password:
        raise RuntimeError("Database is not configured (missing DB_PASSWORD).")
    if settings.cloud_sql_connection_name:
        host = f"/cloudsql/{settings.cloud_sql_connection_name}"
        return psycopg.connect(
            host=host,
            user=settings.db_user,
            dbname=settings.db_name,
            password=settings.db_password,
            row_factory=dict_row,
        )
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        dbname=settings.db_name,
        password=settings.db_password,
        row_factory=dict_row,
    )


def _load_template(name: str) -> str:
    path = _TEMPLATE_DIR / name
    return path.read_text(encoding="utf-8")


def _format_expires(expires_at: datetime) -> str:
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at.astimezone(timezone.utc).strftime("%B %d, %Y")


def build_invite_url(invite_token: str, invited_role: str) -> str:
    base = settings.invite_deep_link_base.rstrip("/")
    role_param = "&role=owner" if invited_role == "owner" else ""
    token = quote(invite_token, safe="")
    return f"{base}/invite-accept?token={token}{role_param}"


def _fetch_email_context(invitation_id: uuid.UUID) -> dict | None:
    with _connection() as conn:
        row = conn.execute(
            """
            SELECT
                i.invitee_email,
                i.role,
                i.relationship_label,
                i.expires_at,
                b.name AS baby_name,
                COALESCE(u.display_name, 'A family member') AS inviter_display_name
            FROM invitations i
            JOIN baby_profiles b ON b.id = i.baby_profile_id AND b.deleted_at IS NULL
            JOIN app_users u ON u.firebase_uid = i.inviter_firebase_uid
            WHERE i.id = %s
              AND i.status = 'pending'
            LIMIT 1
            """,
            (invitation_id,),
        ).fetchone()
    return dict(row) if row else None


def _render_invite_email(ctx: dict, invite_url: str) -> tuple[str, str, str]:
    inviter = ctx["inviter_display_name"]
    baby = ctx["baby_name"]
    invitee = ctx["invitee_email"]
    expires = _format_expires(ctx["expires_at"])
    relationship = ctx.get("relationship_label")
    relationship_line = (
        f"You're listed as: {relationship}." if relationship else ""
    )
    relationship_block = (
        f'<p style="margin:0 0 20px;font-size:15px;color:#6b5b57;">Relationship: {relationship}</p>'
        if relationship
        else ""
    )

    html = _load_template("invite_v1.html")
    text = _load_template("invite_v1.txt")
    replacements = {
        "{{inviter_name}}": inviter,
        "{{baby_name}}": baby,
        "{{invite_url}}": invite_url,
        "{{invitee_email}}": invitee,
        "{{expires_at}}": expires,
        "{{relationship_block}}": relationship_block,
        "{{relationship_line}}": relationship_line,
    }
    for key, value in replacements.items():
        html = html.replace(key, value)
        text = text.replace(key, value)

    subject = f"{inviter} invited you to {baby} on La Nonna"
    return subject, html, text


def send_invite_email(invitation_id: uuid.UUID, invite_token: str) -> None:
    if not settings.mailjet_api_key or not settings.mailjet_api_secret:
        logger.warning(
            "mailjet_not_configured invitation_id=%s — skipping send",
            invitation_id,
        )
        return

    ctx = _fetch_email_context(invitation_id)
    if ctx is None:
        logger.info("invite_email_skip invitation_id=%s not pending", invitation_id)
        return

    invite_url = build_invite_url(invite_token, ctx["role"])
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

    response = httpx.post(
        "https://api.mailjet.com/v3.1/send",
        auth=(settings.mailjet_api_key, settings.mailjet_api_secret),
        json=payload,
        timeout=30.0,
    )
    if response.status_code >= 300:
        logger.error(
            "mailjet_send_failed invitation_id=%s status=%s body=%s",
            invitation_id,
            response.status_code,
            response.text[:500],
        )
        raise RuntimeError(f"Mailjet send failed ({response.status_code})")

    logger.info("invite_email_sent invitation_id=%s", invitation_id)
