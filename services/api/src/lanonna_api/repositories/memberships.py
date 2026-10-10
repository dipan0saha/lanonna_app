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


def lock_baby_profile_for_update(
    baby_profile_id: uuid.UUID,
    conn: Any,
) -> dict[str, Any] | None:
    """Serialize membership changes per baby (e.g. co-owner accept race, M-02)."""
    row = conn.execute(
        """
        SELECT name
        FROM baby_profiles
        WHERE id = %s
          AND deleted_at IS NULL
        FOR UPDATE
        """,
        (baby_profile_id,),
    ).fetchone()
    return dict(row) if row else None


def count_active_owners(baby_profile_id: uuid.UUID, conn=None) -> int:
    sql = """
        SELECT COUNT(*)::int AS n
        FROM baby_memberships
        WHERE baby_profile_id = %s
          AND role = 'owner'
          AND removed_at IS NULL
    """
    if conn is not None:
        row = conn.execute(sql, (baby_profile_id,)).fetchone()
        return int(row["n"]) if row else 0
    with get_connection() as connection:
        row = connection.execute(sql, (baby_profile_id,)).fetchone()
    return int(row["n"]) if row else 0


def get_active_membership(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                m.firebase_uid,
                m.role,
                m.relationship_label,
                m.created_at,
                COALESCE(NULLIF(TRIM(u.display_name), ''), 'Family member') AS display_name
            FROM baby_memberships m
            JOIN app_users u ON u.firebase_uid = m.firebase_uid
            WHERE m.baby_profile_id = %s
              AND m.firebase_uid = %s
              AND m.removed_at IS NULL
            LIMIT 1
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return dict(row) if row else None


def has_removed_membership(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE baby_profile_id = %s
              AND firebase_uid = %s
              AND removed_at IS NOT NULL
            LIMIT 1
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return row is not None


def soft_remove_membership(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    conn=None,
) -> bool:
    sql = """
        UPDATE baby_memberships
        SET removed_at = now(), updated_at = now()
        WHERE baby_profile_id = %s
          AND firebase_uid = %s
          AND removed_at IS NULL
    """
    if conn is not None:
        cur = conn.execute(sql, (baby_profile_id, firebase_uid))
        return cur.rowcount > 0
    with get_connection() as connection:
        cur = connection.execute(sql, (baby_profile_id, firebase_uid))
        return cur.rowcount > 0


def soft_remove_memberships_on_babies(
    baby_profile_ids: list[uuid.UUID],
    conn=None,
) -> None:
    if not baby_profile_ids:
        return
    sql = """
        UPDATE baby_memberships
        SET removed_at = now(), updated_at = now()
        WHERE baby_profile_id = ANY(%s::uuid[]) AND removed_at IS NULL
    """
    if conn is not None:
        conn.execute(sql, (baby_profile_ids,))
    else:
        with get_connection() as connection:
            connection.execute(sql, (baby_profile_ids,))


def soft_remove_all_memberships_for_user(firebase_uid: str, conn=None) -> None:
    sql = """
        UPDATE baby_memberships
        SET removed_at = now(), updated_at = now()
        WHERE firebase_uid = %s AND removed_at IS NULL
    """
    if conn is not None:
        conn.execute(sql, (firebase_uid,))
    else:
        with get_connection() as connection:
            connection.execute(sql, (firebase_uid,))


def reactivate_membership(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    role: str,
    relationship_label: str | None,
    conn=None,
) -> bool:
    sql = """
        UPDATE baby_memberships
        SET removed_at = NULL,
            role = %s,
            relationship_label = %s,
            updated_at = now()
        WHERE baby_profile_id = %s
          AND firebase_uid = %s
          AND removed_at IS NOT NULL
    """
    params = (role, relationship_label, baby_profile_id, firebase_uid)
    if conn is not None:
        cur = conn.execute(sql, params)
        return cur.rowcount > 0
    with get_connection() as connection:
        cur = connection.execute(sql, params)
        return cur.rowcount > 0
