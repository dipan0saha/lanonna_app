from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def list_baby_members(baby_profile_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                m.firebase_uid,
                m.role,
                m.relationship_label,
                m.created_at,
                COALESCE(NULLIF(TRIM(u.display_name), ''), 'Family member') AS display_name,
                u.email
            FROM baby_memberships m
            JOIN app_users u ON u.firebase_uid = m.firebase_uid
            WHERE m.baby_profile_id = %s
              AND m.removed_at IS NULL
            ORDER BY m.role DESC, m.created_at ASC
            """,
            (baby_profile_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def owner_membership_exists(firebase_uid: str, baby_profile_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE baby_profile_id = %s
              AND firebase_uid = %s
              AND role = 'owner'
              AND removed_at IS NULL
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return row is not None
