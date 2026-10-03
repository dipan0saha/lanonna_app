from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from lanonna_api.db import get_connection


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def lookup_token_hash(token: str) -> str:
    return _hash_token(token.strip())


def email_is_member(baby_profile_id: uuid.UUID, email: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships m
            JOIN app_users u ON u.firebase_uid = m.firebase_uid
            WHERE m.baby_profile_id = %s
              AND m.removed_at IS NULL
              AND lower(u.email) = lower(%s)
            LIMIT 1
            """,
            (baby_profile_id, email),
        ).fetchone()
    return row is not None


def list_invitations_for_baby(baby_profile_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, invitee_email, role, relationship_label, status,
                   expires_at, created_at
            FROM invitations
            WHERE baby_profile_id = %s
            ORDER BY created_at DESC
            """,
            (baby_profile_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def revoke_invitation(baby_profile_id: uuid.UUID, invitation_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            """
            UPDATE invitations
            SET status = 'revoked', updated_at = now()
            WHERE id = %s AND baby_profile_id = %s AND status = 'pending'
            """,
            (invitation_id, baby_profile_id),
        )
    return cur.rowcount > 0


def email_has_pending_invite(baby_profile_id: uuid.UUID, email: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM invitations
            WHERE baby_profile_id = %s
              AND lower(invitee_email) = lower(%s)
              AND status = 'pending'
            LIMIT 1
            """,
            (baby_profile_id, email),
        ).fetchone()
    return row is not None


def create_invitation(
    baby_profile_id: uuid.UUID,
    inviter_firebase_uid: str,
    invitee_email: str,
    role: str,
    relationship_label: str | None,
) -> dict[str, Any]:
    token = secrets.token_urlsafe(32)
    token_hash = _hash_token(token)
    expires_at = datetime.now(timezone.utc) + timedelta(days=14)
    invite_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO invitations (
                id, baby_profile_id, inviter_firebase_uid,
                invitee_email, role, relationship_label,
                token_hash, expires_at
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, invitee_email, role, status, expires_at, created_at
            """,
            (
                invite_id,
                baby_profile_id,
                inviter_firebase_uid,
                invitee_email.lower(),
                role,
                relationship_label,
                token_hash,
                expires_at,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("create_invitation returned no row")
    result = dict(row)
    result["invite_token"] = token  # returned once for email worker; not stored plain
    return result


def get_invitation_preview_by_token(token: str) -> dict[str, Any] | None:
    token_hash = lookup_token_hash(token)
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                i.id,
                i.baby_profile_id,
                i.invitee_email,
                i.role,
                i.relationship_label,
                i.status,
                i.expires_at,
                b.name AS baby_name,
                b.lifecycle_status,
                b.expected_birth_date,
                b.actual_birth_date,
                COALESCE(u.display_name, 'A family member') AS inviter_display_name
            FROM invitations i
            JOIN baby_profiles b ON b.id = i.baby_profile_id AND b.deleted_at IS NULL
            JOIN app_users u ON u.firebase_uid = i.inviter_firebase_uid
            WHERE i.token_hash = %s
            LIMIT 1
            """,
            (token_hash,),
        ).fetchone()
    if row is None:
        return None
    data = dict(row)
    if data["status"] != "pending":
        return {"status": "expired"}
    expires_at = data["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        return {"status": "expired"}
    return {
        "status": "pending",
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


def _count_active_owners(baby_profile_id: uuid.UUID, conn) -> int:
    row = conn.execute(
        """
        SELECT COUNT(*)::int AS n
        FROM baby_memberships
        WHERE baby_profile_id = %s
          AND role = 'owner'
          AND removed_at IS NULL
        """,
        (baby_profile_id,),
    ).fetchone()
    return int(row["n"]) if row else 0


def accept_invitation_by_token(
    token: str,
    firebase_uid: str,
    user_email: str | None,
) -> dict[str, Any]:
    if not user_email or not user_email.strip():
        return {"error": "email_mismatch", "invitee_email": None, "signed_in_email": user_email}

    token_hash = lookup_token_hash(token)
    normalized_user_email = user_email.strip().lower()

    with get_connection() as conn:
        inv = conn.execute(
            """
            SELECT *
            FROM invitations
            WHERE token_hash = %s
            LIMIT 1
            """,
            (token_hash,),
        ).fetchone()
        if inv is None:
            return {"error": "not_found"}

        inv = dict(inv)
        if inv["status"] != "pending":
            return {"error": "expired"}
        expires_at = inv["expires_at"]
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            return {"error": "expired"}

        invitee_email = str(inv["invitee_email"]).strip().lower()
        if normalized_user_email != invitee_email:
            return {
                "error": "email_mismatch",
                "invitee_email": invitee_email,
                "signed_in_email": normalized_user_email,
            }

        baby_profile_id = inv["baby_profile_id"]
        existing = conn.execute(
            """
            SELECT role
            FROM baby_memberships
            WHERE baby_profile_id = %s
              AND firebase_uid = %s
              AND removed_at IS NULL
            LIMIT 1
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()

        baby_row = conn.execute(
            "SELECT name FROM baby_profiles WHERE id = %s AND deleted_at IS NULL",
            (baby_profile_id,),
        ).fetchone()
        baby_name = baby_row["name"] if baby_row else "Baby"

        if existing is not None:
            return {
                "already_member": True,
                "baby_profile_id": baby_profile_id,
                "role": existing["role"],
                "baby_name": baby_name,
            }

        invited_role = inv["role"]
        if invited_role == "owner" and _count_active_owners(baby_profile_id, conn) >= 2:
            return {"error": "max_owners"}

        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role, relationship_label
            )
            VALUES (%s, %s, %s, %s)
            """,
            (
                baby_profile_id,
                firebase_uid,
                invited_role,
                inv["relationship_label"],
            ),
        )
        conn.execute(
            """
            UPDATE invitations
            SET status = 'accepted',
                updated_at = now()
            WHERE id = %s
            """,
            (inv["id"],),
        )

    return {
        "already_member": False,
        "baby_profile_id": baby_profile_id,
        "role": invited_role,
        "baby_name": baby_name,
        "inviter_firebase_uid": inv["inviter_firebase_uid"],
    }


