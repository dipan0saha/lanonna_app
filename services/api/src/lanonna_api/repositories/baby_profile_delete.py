from __future__ import annotations

import uuid

from lanonna_api.db import get_connection
from lanonna_api.repositories.memberships import soft_remove_memberships_on_babies


def soft_delete_baby_profiles(
    baby_profile_ids: list[uuid.UUID],
    conn=None,
) -> None:
    """Soft-delete baby profiles and end all memberships on them.

    Same SQL slice used for sole-owned babies during account delete and for
    explicit owner-initiated baby profile deletion.
    """
    if not baby_profile_ids:
        return

    def _run(connection) -> None:
        connection.execute(
            """
            UPDATE invitations
            SET status = 'revoked', updated_at = now()
            WHERE baby_profile_id = ANY(%s::uuid[]) AND status = 'pending'
            """,
            (baby_profile_ids,),
        )
        soft_remove_memberships_on_babies(baby_profile_ids, conn=connection)
        connection.execute(
            """
            UPDATE baby_profiles
            SET deleted_at = now(), updated_at = now()
            WHERE id = ANY(%s::uuid[]) AND deleted_at IS NULL
            """,
            (baby_profile_ids,),
        )

    if conn is not None:
        _run(conn)
    else:
        with get_connection() as connection:
            _run(connection)
