from __future__ import annotations

import uuid

from lanonna_api.db import get_connection
from lanonna_api.repositories.active_participants import purge_participation
from lanonna_api.repositories.baby_profile_delete import soft_delete_baby_profiles
from lanonna_api.repositories.memberships import soft_remove_all_memberships_for_user


def account_is_tombstoned(firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT deleted_at
            FROM app_users
            WHERE firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchone()
    return row is not None and row["deleted_at"] is not None


_SOLE_OWNED_BABIES_SQL = """
SELECT b.id, b.name
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
ORDER BY b.name NULLS LAST, b.created_at, b.id
"""


def list_sole_owned_baby_ids(firebase_uid: str) -> list[uuid.UUID]:
    return [uuid.UUID(row["id"]) for row in list_sole_owned_baby_names(firebase_uid)]


def list_sole_owned_baby_names(firebase_uid: str) -> list[dict[str, str | None]]:
    """``name`` is ``None`` for an unnamed baby; the app shows its fallback."""
    with get_connection() as conn:
        rows = conn.execute(_SOLE_OWNED_BABIES_SQL, (firebase_uid,)).fetchall()
    return [
        {"id": str(row["id"]), "name": row["name"]}
        for row in rows
    ]


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
            soft_delete_baby_profiles(sole_owned, conn=conn)
        soft_remove_all_memberships_for_user(firebase_uid, conn=conn)
        purge_participation(conn, firebase_uid)
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
