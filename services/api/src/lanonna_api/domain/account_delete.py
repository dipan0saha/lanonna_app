from __future__ import annotations

import uuid
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth

from lanonna_api.db import get_connection


def _sole_owned_baby_ids(firebase_uid: str) -> list[uuid.UUID]:
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


def delete_account_eligibility(firebase_uid: str) -> dict[str, Any]:
    sole = _sole_owned_baby_ids(firebase_uid)
    blockers = [f"sole_owner_of_baby:{baby_id}" for baby_id in sole]
    return {"allowed": len(blockers) == 0, "blockers": blockers}


def delete_account(firebase_uid: str) -> None:
    eligibility = delete_account_eligibility(firebase_uid)
    if not eligibility["allowed"]:
        raise PermissionError(
            "Transfer or remove owned baby profiles before deleting your account."
        )

    with get_connection() as conn:
        conn.execute(
            """
            UPDATE invitations
            SET status = 'revoked'
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

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    firebase_auth.delete_user(firebase_uid)
