"""Co-owner accept uses baby row lock before owner count (M-02)."""

import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

from lanonna_api.repositories.invitations import accept_invitation_by_token


def _pending_invite_row(baby_id: uuid.UUID) -> dict:
    return {
        "id": uuid.uuid4(),
        "baby_profile_id": baby_id,
        "invitee_email": "co@test.com",
        "role": "owner",
        "status": "pending",
        "expires_at": datetime.now(timezone.utc) + timedelta(days=7),
        "relationship_label": "Dad",
        "inviter_firebase_uid": "owner-uid",
        "token_hash": "hash",
    }


@contextmanager
def _mock_conn(inv_row: dict, owner_count: int):
    conn = MagicMock()
    conn.execute.return_value.fetchone.side_effect = [
        inv_row,
        None,
        None,
        None,
    ]

    def execute_side_effect(sql, params=None):
        result = MagicMock()
        if "FROM invitations" in sql and "token_hash" in sql:
            result.fetchone.return_value = inv_row
        elif "baby_memberships" in sql and "removed_at IS NULL" in sql and "firebase_uid" in sql:
            result.fetchone.return_value = None
        elif "removed_at IS NOT NULL" in sql:
            result.fetchone.return_value = None
        elif "FOR UPDATE" in sql:
            result.fetchone.return_value = {"name": "Baby"}
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
            with patch(
                "lanonna_api.repositories.invitations.count_active_owners",
                return_value=owner_count,
            ) as count_owners:
                with patch(
                    "lanonna_api.repositories.invitations.lock_baby_profile_for_update",
                    return_value={"name": "Baby"},
                ) as lock_baby:
                    yield conn, count_owners, lock_baby


def test_accept_owner_invite_locks_baby_before_owner_count():
    baby_id = uuid.uuid4()
    inv = _pending_invite_row(baby_id)
    order: list[str] = []

    with _mock_conn(inv, owner_count=1) as (_, count_owners, lock_baby):
        lock_baby.side_effect = lambda bid, c: (
            order.append("lock") or {"name": "Baby"}
        )
        count_owners.side_effect = lambda bid, c=None: (
            order.append("count") or 1
        )

        result = accept_invitation_by_token("token", "uid-co", "co@test.com")

    assert result.get("error") is None
    assert order == ["lock", "count"]
    lock_baby.assert_called_once()
    count_owners.assert_called_once()


def test_accept_owner_invite_returns_max_owners_after_lock_when_full():
    baby_id = uuid.uuid4()
    inv = _pending_invite_row(baby_id)

    with _mock_conn(inv, owner_count=2) as (_, count_owners, lock_baby):
        result = accept_invitation_by_token("token", "uid-co", "co@test.com")

    assert result == {"error": "max_owners"}
    lock_baby.assert_called_once()
    count_owners.assert_called_once()
