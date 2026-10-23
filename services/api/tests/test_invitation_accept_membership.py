"""Accept is idempotent for existing members before invitee email is checked."""

import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest

from lanonna_api.domain.invitations import accept_invitation

from lanonna_api.repositories.invitations import accept_invitation_by_token


def _accepted_invite_row(baby_id: uuid.UUID) -> dict:
    return {
        "id": uuid.uuid4(),
        "baby_profile_id": baby_id,
        "invitee_email": "follower@test.com",
        "role": "follower",
        "status": "accepted",
        "expires_at": datetime.now(timezone.utc) + timedelta(days=7),
        "relationship_label": "Parent",
        "inviter_firebase_uid": "owner-uid",
        "token_hash": "hash",
    }


@contextmanager
def _mock_conn(inv_row: dict, membership_role: str):
    conn = MagicMock()

    def execute_side_effect(sql, params=None):
        result = MagicMock()
        if "FROM invitations" in sql and "token_hash" in sql:
            result.fetchone.return_value = inv_row
        elif (
            "baby_memberships" in sql
            and "removed_at IS NULL" in sql
            and "firebase_uid" in sql
        ):
            result.fetchone.return_value = {"role": membership_role}
        elif "FROM baby_profiles" in sql:
            result.fetchone.return_value = {"name": "Luna"}
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute_side_effect

    with patch(
        "lanonna_api.repositories.invitations.get_connection"
    ) as get_conn:
        get_conn.return_value.__enter__.return_value = conn
        with patch(
            "lanonna_api.repositories.invitations.lookup_token_hash",
            return_value="hash",
        ):
            yield conn


def test_accept_returns_already_member_when_signed_in_user_is_not_invitee():
    baby_id = uuid.uuid4()
    inv = _accepted_invite_row(baby_id)

    with _mock_conn(inv, membership_role="owner"):
        result = accept_invitation_by_token(
            "token",
            "owner-uid",
            "owner@test.com",
        )

    assert result["already_member"] is True
    assert result["baby_profile_id"] == baby_id
    assert result["role"] == "owner"
    assert result["baby_name"] == "Luna"


def _write_statements(conn: MagicMock) -> list[str]:
    statements = [str(call.args[0]) for call in conn.execute.call_args_list]
    return [
        sql
        for sql in statements
        if any(word in sql.upper() for word in ("UPDATE", "INSERT", "DELETE", "FOR UPDATE"))
    ]


@pytest.mark.parametrize(
    ("status", "expires_in"),
    [
        ("pending", timedelta(days=7)),
        ("pending", timedelta(days=-1)),
        ("revoked", timedelta(days=7)),
        ("expired", timedelta(days=-1)),
        ("accepted", timedelta(days=7)),
    ],
)
def test_member_opening_invite_for_someone_else_writes_nothing(status, expires_in):
    baby_id = uuid.uuid4()
    inv = {
        **_accepted_invite_row(baby_id),
        "role": "owner",
        "status": status,
        "expires_at": datetime.now(timezone.utc) + expires_in,
    }

    with _mock_conn(inv, membership_role="follower") as conn:
        result = accept_invitation_by_token("token", "follower-uid", "aunt@test.com")

    assert result == {
        "already_member": True,
        "baby_profile_id": baby_id,
        "role": "follower",
        "baby_name": "Luna",
    }
    assert _write_statements(conn) == []


def test_already_member_accept_does_not_notify_inviter():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.accept_invitation_by_token",
            return_value={
                "already_member": True,
                "baby_profile_id": baby_id,
                "role": "follower",
                "baby_name": "Luna",
            },
        ),
        patch("lanonna_api.domain.invitations.safe_enqueue_notify_user") as notify,
    ):
        accept_invitation("token", "follower-uid", "aunt@test.com")

    notify.assert_not_called()
