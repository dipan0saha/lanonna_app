from __future__ import annotations

from lanonna_api.db import get_connection


def expire_stale_pending_invitations() -> int:
    """Mark pending invites past expires_at as expired. Returns rows updated."""
    with get_connection() as conn:
        result = conn.execute(
            """
            UPDATE invitations
            SET status = 'expired', updated_at = now()
            WHERE status = 'pending'
              AND expires_at < now()
            """
        )
    return int(result.rowcount or 0)
