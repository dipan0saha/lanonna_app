from __future__ import annotations

import uuid

from lanonna_api.db import get_connection


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


def soft_delete_account_rows(firebase_uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE invitations
            SET status = 'revoked', updated_at = now()
            WHERE inviter_firebase_uid = %s AND status = 'pending'
            """,
            (firebase_uid,),
        )
        conn.execute(
            """
            UPDATE baby_memberships
            SET removed_at = now(), updated_at = now()
            WHERE firebase_uid = %s AND removed_at IS NULL
            """,
            (firebase_uid,),
        )
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
