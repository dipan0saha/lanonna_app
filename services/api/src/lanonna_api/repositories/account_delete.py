from __future__ import annotations

import uuid

from lanonna_api.db import get_connection
from lanonna_api.repositories.memberships import (
    soft_remove_all_memberships_for_user,
    soft_remove_memberships_on_babies,
)


def list_sole_owned_baby_ids(firebase_uid: str) -> list[uuid.UUID]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT b.id
            FROM baby_profiles b
            JOIN baby_memberships m ON m.baby_profile_id = b.id
            WHERE m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
              AND (
                SELECT COUNT(*)::int
                FROM baby_memberships om
                WHERE om.baby_profile_id = b.id
                  AND om.role = 'owner'
                  AND om.removed_at IS NULL
              ) = 1
            """,
            (firebase_uid,),
        ).fetchall()
    return [row["id"] for row in rows]


def soft_delete_account_rows(
    firebase_uid: str,
    sole_owned_baby_ids: list[uuid.UUID] | None = None,
) -> None:
    sole_owned = sole_owned_baby_ids or []
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE invitations
            SET status = 'revoked', updated_at = now()
            WHERE inviter_firebase_uid = %s AND status = 'pending'
            """,
            (firebase_uid,),
        )
        if sole_owned:
            conn.execute(
                """
                UPDATE invitations
                SET status = 'revoked', updated_at = now()
                WHERE baby_profile_id = ANY(%s::uuid[]) AND status = 'pending'
                """,
                (sole_owned,),
            )
            soft_remove_memberships_on_babies(sole_owned, conn=conn)
            conn.execute(
                """
                UPDATE baby_profiles
                SET deleted_at = now(), updated_at = now()
                WHERE id = ANY(%s::uuid[]) AND deleted_at IS NULL
                """,
                (sole_owned,),
            )
        soft_remove_all_memberships_for_user(firebase_uid, conn=conn)
        conn.execute(
            """
            UPDATE app_users
            SET display_name = 'Deleted user',
                email = NULL,
                avatar_url = NULL,
                deleted_at = now()
            WHERE firebase_uid = %s
            """,
            (firebase_uid,),
        )
