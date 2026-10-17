from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.domain.errors import (
    ConflictError,
    ErrorCode,
    ForbiddenError,
    GoneError,
    NotFoundError,
)
from lanonna_api.domain.owner_limit import (
    ensure_owner_slot_for_accept,
    owner_slots_remaining,
)
from lanonna_api.repositories._paging import limit_offset_clause
from lanonna_api.repositories.memberships import (
    count_active_owners,
    lock_baby_profile_for_update,
    reactivate_membership,
)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def lookup_token_hash(token: str) -> str:
    return _hash_token(token.strip())


def list_invitations_for_baby(
    baby_profile_id: uuid.UUID,
    *,
    limit: int | None = None,
    offset: int = 0,
) -> list[dict[str, Any]]:
    paging, paging_params = limit_offset_clause(limit, offset)
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT id, invitee_email, role, relationship_label, status,
                   expires_at, created_at, email_sent_at,
                   email_delivery_status, email_last_error, email_send_attempts
            FROM invitations
            WHERE baby_profile_id = %s
            ORDER BY created_at DESC, id DESC
            {paging}
            """,
            (baby_profile_id, *paging_params),
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


INVITE_EXPIRY = timedelta(days=14)


def load_invite_targets(
    baby_profile_id: uuid.UUID,
    emails: list[str],
) -> dict[str, dict[str, Any]]:
    """Membership and pending-invite state for every email in one statement.

    Keys are the normalized (trimmed, lower-case) emails. ``pending_id`` is the
    baby's pending invitation for that email, if any; ``pending_email_sent``
    tells whether its email was already delivered.
    """
    normalized = list(dict.fromkeys(e.strip().lower() for e in emails if e.strip()))
    if not normalized:
        return {}
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                e.email,
                EXISTS (
                    SELECT 1
                    FROM baby_memberships m
                    JOIN app_users u ON u.firebase_uid = m.firebase_uid
                    WHERE m.baby_profile_id = %s
                      AND m.removed_at IS NULL
                      AND lower(u.email) = e.email
                ) AS is_member,
                p.id AS pending_id,
                (p.email_sent_at IS NOT NULL) AS pending_email_sent
            FROM unnest(%s::text[]) AS e(email)
            LEFT JOIN invitations p
              ON p.baby_profile_id = %s
             AND lower(p.invitee_email) = e.email
             AND p.status = 'pending'
            """,
            (baby_profile_id, normalized, baby_profile_id),
        ).fetchall()
    return {
        row["email"]: {
            "is_member": bool(row["is_member"]),
            "pending_id": row["pending_id"],
            "pending_email_sent": bool(row["pending_email_sent"]),
        }
        for row in rows
    }


def _prepare_for_resend(
    conn: Any,
    baby_profile_id: uuid.UUID,
    invitation_ids: list[uuid.UUID],
) -> set[uuid.UUID]:
    """Clear stale send claims on still-undelivered pending invites; ids that qualified."""
    if not invitation_ids:
        return set()
    rows = conn.execute(
        """
        UPDATE invitations
        SET email_send_claimed_at = NULL,
            email_delivery_status = 'pending',
            email_last_error = NULL,
            updated_at = now()
        WHERE id = ANY(%s)
          AND baby_profile_id = %s
          AND status = 'pending'
          AND email_sent_at IS NULL
        RETURNING id
        """,
        (invitation_ids, baby_profile_id),
    ).fetchall()
    return {row["id"] for row in rows}


def prepare_invitation_for_resend(
    baby_profile_id: uuid.UUID,
    invitation_id: uuid.UUID,
) -> uuid.UUID | None:
    """Allow another delivery attempt for one undelivered pending invite."""
    with get_connection() as conn:
        prepared = _prepare_for_resend(conn, baby_profile_id, [invitation_id])
    return invitation_id if invitation_id in prepared else None


def _count_reserved_owner_slots(conn: Any, baby_profile_id: uuid.UUID) -> tuple[int, int]:
    """(active owners, pending unexpired owner invites) for the owner limit."""
    row = conn.execute(
        """
        SELECT
            (SELECT COUNT(*)::int FROM baby_memberships
             WHERE baby_profile_id = %s AND role = 'owner' AND removed_at IS NULL)
                AS active_owners,
            (SELECT COUNT(*)::int FROM invitations
             WHERE baby_profile_id = %s AND role = 'owner' AND status = 'pending'
               AND expires_at > now())
                AS pending_owner_invites
        """,
        (baby_profile_id, baby_profile_id),
    ).fetchone()
    return int(row["active_owners"]), int(row["pending_owner_invites"])


def write_batch_invitations(
    baby_profile_id: uuid.UUID,
    inviter_firebase_uid: str,
    *,
    resend_ids: list[uuid.UUID],
    new_invites: list[tuple[str, str, str | None]],
) -> tuple[set[uuid.UUID], dict[str, uuid.UUID], set[str]]:
    """Re-arm undelivered invites and insert new ones in one transaction.

    ``new_invites`` rows are ``(normalized_email, role, relationship_label)``.
    Returns the re-armed ids, ``email -> new invitation id``, and the emails of
    new owner invites refused by the owner limit (``domain/owner_limit.py``:
    active owners plus pending owner invites, counted under the baby row lock,
    in submission order). An email that gained a pending invite concurrently is
    left out of the map (the partial unique index ``uq_invitations_pending_email``
    decides), so callers report it as a duplicate instead of failing the batch.
    """
    with get_connection() as conn:
        prepared = _prepare_for_resend(conn, baby_profile_id, resend_ids)
        created: dict[str, uuid.UUID] = {}
        over_owner_limit: set[str] = set()
        if any(role == "owner" for _, role, _ in new_invites):
            lock_baby_profile_for_update(baby_profile_id, conn)
            slots = owner_slots_remaining(*_count_reserved_owner_slots(conn, baby_profile_id))
            allowed: list[tuple[str, str, str | None]] = []
            for invite in new_invites:
                if invite[1] == "owner":
                    if slots == 0:
                        over_owner_limit.add(invite[0])
                        continue
                    slots -= 1
                allowed.append(invite)
            new_invites = allowed
        if new_invites:
            expires_at = datetime.now(timezone.utc) + INVITE_EXPIRY
            tokens = [secrets.token_urlsafe(32) for _ in new_invites]
            rows = conn.execute(
                """
                INSERT INTO invitations (
                    baby_profile_id, inviter_firebase_uid,
                    invitee_email, role, relationship_label,
                    token_hash, expires_at, email_invite_token
                )
                SELECT %s, %s, r.email, r.role, r.relationship_label,
                       r.token_hash, %s, r.token
                FROM unnest(%s::text[], %s::text[], %s::text[], %s::text[], %s::text[])
                    AS r(email, role, relationship_label, token_hash, token)
                ON CONFLICT (baby_profile_id, lower(invitee_email))
                    WHERE status = 'pending'
                    DO NOTHING
                RETURNING id, invitee_email
                """,
                (
                    baby_profile_id,
                    inviter_firebase_uid,
                    expires_at,
                    [email for email, _, _ in new_invites],
                    [role for _, role, _ in new_invites],
                    [label for _, _, label in new_invites],
                    [_hash_token(token) for token in tokens],
                    tokens,
                ),
            ).fetchall()
            created = {row["invitee_email"]: row["id"] for row in rows}
    return prepared, created, over_owner_limit


def fetch_invitation_preview_row(token: str) -> dict[str, Any] | None:
    """Load invitation + baby + inviter display fields for preview/accept policy."""
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
                NULLIF(TRIM(u.display_name), '') AS inviter_display_name
            FROM invitations i
            JOIN baby_profiles b ON b.id = i.baby_profile_id AND b.deleted_at IS NULL
            JOIN app_users u ON u.firebase_uid = i.inviter_firebase_uid
            WHERE i.token_hash = %s
            LIMIT 1
            """,
            (token_hash,),
        ).fetchone()
    return dict(row) if row else None


def _email_mismatch(invitee_email: str | None, signed_in_email: str | None) -> ForbiddenError:
    return ForbiddenError(
        ErrorCode.EMAIL_MISMATCH,
        "Signed-in email does not match the invitation",
        params={"invitee_email": invitee_email, "signed_in_email": signed_in_email},
    )


def _invitation_not_found() -> NotFoundError:
    return NotFoundError(ErrorCode.NOT_FOUND, "Invitation not found")


def accept_invitation_by_token(
    token: str,
    firebase_uid: str,
    user_email: str | None,
) -> dict[str, Any]:
    """Accept an invitation in one transaction; raises typed errors on refusal.

    Refusals: ``not_found`` (404), ``email_mismatch`` (403, invitee and
    signed-in emails in ``params``), ``revoked`` / ``expired`` (410),
    ``already_used`` / ``max_owners`` (409). A caller who is already a member
    gets ``already_member: True`` instead of an error.
    """
    if not user_email or not user_email.strip():
        raise _email_mismatch(None, user_email)

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
            raise _invitation_not_found()

        inv = dict(inv)
        invitee_email = str(inv["invitee_email"]).strip().lower()
        if normalized_user_email != invitee_email:
            raise _email_mismatch(invitee_email, normalized_user_email)

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
        if baby_row is None:
            raise _invitation_not_found()
        baby_name = baby_row["name"]

        if existing is not None:
            return {
                "already_member": True,
                "baby_profile_id": baby_profile_id,
                "role": existing["role"],
                "baby_name": baby_name,
            }

        invite_status = inv["status"]
        if invite_status == "revoked":
            raise GoneError(ErrorCode.REVOKED, "Invitation revoked")
        if invite_status == "accepted":
            raise ConflictError(ErrorCode.ALREADY_USED, "Invitation already accepted")
        if invite_status != "pending":
            raise GoneError(ErrorCode.EXPIRED, "Invitation expired")

        expires_at = inv["expires_at"]
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            raise GoneError(ErrorCode.EXPIRED, "Invitation expired")

        invited_role = inv["role"]
        if invited_role == "owner":
            # Serialize concurrent co-owner accepts per baby: the lock is held until this
            # transaction commits, so the owner count below cannot go stale (M-02).
            if lock_baby_profile_for_update(baby_profile_id, conn) is None:
                raise _invitation_not_found()
            ensure_owner_slot_for_accept(count_active_owners(baby_profile_id, conn))

        removed_row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE baby_profile_id = %s
              AND firebase_uid = %s
              AND removed_at IS NOT NULL
            LIMIT 1
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
        if removed_row is not None:
            reactivate_membership(
                baby_profile_id,
                firebase_uid,
                invited_role,
                inv["relationship_label"],
                conn=conn,
            )
        else:
            conn.execute(
                """
                INSERT INTO baby_memberships (
                    baby_profile_id, firebase_uid, role, relationship_label, joined_via
                )
                VALUES (%s, %s, %s, %s, 'invite')
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
