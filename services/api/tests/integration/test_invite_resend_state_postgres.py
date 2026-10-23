"""``can_resend_email`` on the owner's invitation list is server truth (#410)."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.invitations import list_invitations_for_baby
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_OWNER = "invite-owner"


def _baby() -> uuid.UUID:
    resolve_app_user(_OWNER, "invite-owner@example.test")
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)"
            " VALUES (%s, 'Parker', 'expecting', %s)",
            (baby_id, _OWNER),
        )
    return baby_id


def _invite(
    baby_id: uuid.UUID,
    tag: str,
    *,
    status: str = "pending",
    delivery: str,
    sent: bool = False,
    idle: str = "0 minutes",
) -> uuid.UUID:
    inv_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO invitations (
                id, baby_profile_id, inviter_firebase_uid, invitee_email, role,
                token_hash, expires_at, status, email_sent_at,
                email_delivery_status, updated_at
            )
            VALUES (%s, %s, %s, %s, 'follower', %s, now() + interval '1 day', %s,
                    CASE WHEN %s THEN now() END, %s, now() - %s::interval)
            """,
            (
                inv_id,
                baby_id,
                _OWNER,
                f"{tag}@example.test",
                uuid.uuid4().hex,
                status,
                sent,
                delivery,
                idle,
            ),
        )
    return inv_id


def test_resend_offered_only_when_no_email_is_on_its_way():
    baby = _baby()
    expected = {
        _invite(baby, "sending", delivery="pending"): False,
        _invite(baby, "stuck", delivery="pending", idle="20 minutes"): True,
        _invite(baby, "failed", delivery="failed"): True,
        _invite(baby, "sent", delivery="sent", sent=True): False,
        _invite(baby, "revoked", status="revoked", delivery="failed"): False,
    }
    rows = {row["id"]: row["can_resend_email"] for row in list_invitations_for_baby(baby)}
    assert rows == expected
