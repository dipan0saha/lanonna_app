from __future__ import annotations

import uuid
from enum import StrEnum
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.repositories._paging import limit_offset_clause
from lanonna_api.repositories.active_participants import (
    purge_participation,
    purge_participation_on_baby,
)


def list_baby_members(
    baby_profile_id: uuid.UUID,
    *,
    limit: int | None = None,
    offset: int = 0,
) -> list[dict[str, Any]]:
    paging, paging_params = limit_offset_clause(limit, offset)
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                m.firebase_uid,
                m.role,
                m.created_at,
                NULLIF(TRIM(u.display_name), '') AS display_name
            FROM baby_memberships m
            JOIN app_users u ON u.firebase_uid = m.firebase_uid
            WHERE m.baby_profile_id = %s
              AND m.removed_at IS NULL
            ORDER BY m.role DESC, m.created_at ASC, m.firebase_uid ASC
            {paging}
            """,
            (baby_profile_id, *paging_params),
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


def lock_membership_for_user_for_update(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    conn: Any,
) -> dict[str, Any] | None:
    row = conn.execute(
        """
        SELECT role
        FROM baby_memberships
        WHERE baby_profile_id = %s
          AND firebase_uid = %s
          AND removed_at IS NULL
        FOR UPDATE
        """,
        (baby_profile_id, firebase_uid),
    ).fetchone()
    return dict(row) if row else None


def lock_baby_profile_for_update(
    baby_profile_id: uuid.UUID,
    conn: Any,
) -> dict[str, Any] | None:
    """Serialize membership changes and baby hard-delete per profile (M-02, #442).

    Writers that insert baby-scoped child rows take ``lock_baby_profile_for_key_share``
    in the same transaction first. ``FOR UPDATE`` blocks ``FOR KEY SHARE``, so delete
    waits for in-flight child writes; child writes wait for delete, then see the row
    gone instead of hitting ``baby_profiles`` FK violations under READ COMMITTED.
    """
    row = conn.execute(
        """
        SELECT name
        FROM baby_profiles
        WHERE id = %s
        FOR UPDATE
        """,
        (baby_profile_id,),
    ).fetchone()
    return dict(row) if row else None


def lock_baby_profile_for_key_share(
    baby_profile_id: uuid.UUID,
    conn: Any,
) -> dict[str, Any] | None:
    """Lock the baby row for a child INSERT/UPDATE (see ``lock_baby_profile_for_update``)."""
    row = conn.execute(
        """
        SELECT id
        FROM baby_profiles
        WHERE id = %s
        FOR KEY SHARE
        """,
        (baby_profile_id,),
    ).fetchone()
    return dict(row) if row else None


def ensure_baby_profile_for_child_write(
    baby_profile_id: uuid.UUID,
    conn: Any,
    *,
    row_lock_held: bool = False,
) -> None:
    """Raise ``LookupError`` when the baby was hard-deleted before the child write."""
    if row_lock_held:
        return
    if lock_baby_profile_for_key_share(baby_profile_id, conn) is None:
        raise LookupError("Baby profile not found.")


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
            SELECT m.firebase_uid, m.role
            FROM baby_memberships m
            WHERE m.baby_profile_id = %s
              AND m.firebase_uid = %s
              AND m.removed_at IS NULL
            LIMIT 1
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return dict(row) if row else None


def membership_access_ended(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> bool:
    """True when the user was removed from the baby or the baby was deleted.

    Baby delete is a hard delete (memberships cascade away), so a missing
    baby is ended access too: clients get ``membership_ended`` and drop it.
    """
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                NOT EXISTS (SELECT 1 FROM baby_profiles WHERE id = %(baby)s)
                OR EXISTS (
                    SELECT 1
                    FROM baby_memberships
                    WHERE baby_profile_id = %(baby)s
                      AND firebase_uid = %(uid)s
                      AND removed_at IS NOT NULL
                ) AS ended
            """,
            {"baby": baby_profile_id, "uid": firebase_uid},
        ).fetchone()
    return bool(row["ended"])


def soft_remove_membership(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    conn=None,
) -> bool:
    """End one membership and drop that person's presence on this baby."""
    sql = """
        UPDATE baby_memberships
        SET removed_at = now(), updated_at = now()
        WHERE baby_profile_id = %s
          AND firebase_uid = %s
          AND removed_at IS NULL
    """

    def _run(connection) -> bool:
        cur = connection.execute(sql, (baby_profile_id, firebase_uid))
        if cur.rowcount == 0:
            return False
        purge_participation_on_baby(connection, baby_profile_id, firebase_uid)
        return True

    if conn is not None:
        return _run(conn)
    with get_connection() as connection:
        return _run(connection)


class OwnLeaveOutcome(StrEnum):
    LEFT = "left"
    NOT_MEMBER = "not_member"
    SOLE_OWNER = "sole_owner"


def soft_remove_own_membership(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    conn: Any | None = None,
) -> OwnLeaveOutcome:
    """Leave a baby: check the owner count and end the membership in one transaction.

    Takes the baby row lock first (same order as baby delete and co-owner
    accept), so two co-owners leaving at once cannot both pass the count and
    orphan the profile.
    """

    def _run(connection: Any) -> OwnLeaveOutcome:
        if lock_baby_profile_for_update(baby_profile_id, connection) is None:
            return OwnLeaveOutcome.NOT_MEMBER
        membership = lock_membership_for_user_for_update(
            baby_profile_id, firebase_uid, connection
        )
        if membership is None:
            return OwnLeaveOutcome.NOT_MEMBER
        if (
            membership["role"] == "owner"
            and count_active_owners(baby_profile_id, connection) <= 1
        ):
            return OwnLeaveOutcome.SOLE_OWNER
        if not soft_remove_membership(
            baby_profile_id, firebase_uid, conn=connection
        ):
            return OwnLeaveOutcome.NOT_MEMBER
        return OwnLeaveOutcome.LEFT

    if conn is not None:
        return _run(conn)
    with get_connection() as connection:
        return _run(connection)


def soft_remove_all_memberships_for_user(firebase_uid: str, conn=None) -> None:
    """End every membership for one account and drop their presence everywhere."""
    sql = """
        UPDATE baby_memberships
        SET removed_at = now(), updated_at = now()
        WHERE firebase_uid = %s AND removed_at IS NULL
    """

    def _run(connection) -> None:
        connection.execute(sql, (firebase_uid,))
        purge_participation(connection, firebase_uid)

    if conn is not None:
        _run(conn)
    else:
        with get_connection() as connection:
            _run(connection)


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
