from __future__ import annotations

import logging

from lanonna_worker.db import get_connection

logger = logging.getLogger("lanonna.worker.invite_cleanup")


def expire_stale_pending_invitations() -> int:
    with get_connection() as conn:
        result = conn.execute(
            """
            UPDATE invitations
            SET status = 'expired', updated_at = now()
            WHERE status = 'pending'
              AND expires_at < now()
            """
        )
    count = int(result.rowcount or 0)
    logger.info("expire_stale_pending_invitations updated=%s", count)
    return count
