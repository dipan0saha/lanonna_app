from __future__ import annotations

import uuid
from typing import Any

import psycopg

from lanonna_api.db import get_connection
from lanonna_api.repositories._paging import limit_offset_clause

# Active owners of baby `b`, computed inside the same statement as the baby row
# so list endpoints never issue a follow-up query per baby. Every baby summary
# row carries it; `baby_summary_from_row` derives `can_leave` from it.
ACTIVE_OWNER_COUNT_COLUMN = """
    (
        SELECT COUNT(*)::int
        FROM baby_memberships owners
        WHERE owners.baby_profile_id = b.id
          AND owners.role = 'owner'
          AND owners.removed_at IS NULL
    ) AS active_owner_count
"""

# The one column list behind every baby summary row: the baby (`b`) seen
# through the caller's membership (`m`). Reads, the create read-back and the
# PATCH ``RETURNING`` all use it, so every response carries the caller's
# stored role and relationship_label rather than a hand-filled stand-in.
BABY_SUMMARY_COLUMNS = f"""
    b.id,
    b.name,
    b.gender,
    b.expected_birth_date,
    b.actual_birth_date,
    b.lifecycle_status,
    b.avatar_url,
    m.role,
    m.relationship_label,
    {ACTIVE_OWNER_COUNT_COLUMN}
"""

_ACTIVE_MEMBERSHIP_JOIN = """
    FROM baby_profiles b
    JOIN baby_memberships m ON m.baby_profile_id = b.id
    WHERE b.id = %s
      AND m.firebase_uid = %s
      AND m.removed_at IS NULL
      AND b.deleted_at IS NULL
"""


def _fetch_baby_summary_row(
    conn: psycopg.Connection[Any],
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    owner_only: bool,
) -> dict[str, Any] | None:
    role_clause = "AND m.role = 'owner'" if owner_only else ""
    row = conn.execute(
        f"""
        SELECT {BABY_SUMMARY_COLUMNS}
        {_ACTIVE_MEMBERSHIP_JOIN}
        {role_clause}
        """,
        (baby_profile_id, firebase_uid),
    ).fetchone()
    return dict(row) if row else None


def list_babies_for_user(
    firebase_uid: str,
    *,
    limit: int | None = None,
    offset: int = 0,
) -> list[dict[str, Any]]:
    paging, paging_params = limit_offset_clause(limit, offset)
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT {BABY_SUMMARY_COLUMNS}
            FROM baby_memberships m
            JOIN baby_profiles b ON b.id = m.baby_profile_id
            WHERE m.firebase_uid = %s
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
            ORDER BY b.created_at ASC, b.id ASC
            {paging}
            """,
            (firebase_uid, *paging_params),
        ).fetchall()
    return [dict(row) for row in rows]


def create_baby_with_owner_membership(
    firebase_uid: str,
    name: str | None,
    gender: str,
    expected_birth_date,
    actual_birth_date,
    lifecycle_status: str,
    relationship_label: str | None = None,
) -> dict[str, Any]:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (
                id, name, gender, expected_birth_date,
                actual_birth_date, lifecycle_status,
                created_by_firebase_uid
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                baby_id,
                name,
                gender,
                expected_birth_date,
                actual_birth_date,
                lifecycle_status,
                firebase_uid,
            ),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role, relationship_label, joined_via
            )
            VALUES (%s, %s, 'owner', %s, 'created')
            """,
            (baby_id, firebase_uid, relationship_label),
        )
        row = _fetch_baby_summary_row(conn, firebase_uid, baby_id, owner_only=True)
    if row is None:
        raise RuntimeError("create_baby returned no row")
    return row


def update_baby_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any] | None:
    if not fields:
        return get_baby_for_owner(firebase_uid, baby_profile_id)

    set_parts = []
    values: list[Any] = []
    for key, value in fields.items():
        set_parts.append(f"{key} = %s")
        values.append(value)
    set_parts.append("updated_at = now()")
    values.extend([baby_profile_id, firebase_uid])

    with get_connection() as conn:
        row = conn.execute(
            f"""
            UPDATE baby_profiles b
            SET {", ".join(set_parts)}
            FROM baby_memberships m
            WHERE b.id = m.baby_profile_id
              AND b.id = %s
              AND m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
            RETURNING {BABY_SUMMARY_COLUMNS}
            """,
            values,
        ).fetchone()
    return dict(row) if row else None


def get_baby_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        return _fetch_baby_summary_row(
            conn, firebase_uid, baby_profile_id, owner_only=True
        )


def get_baby_membership(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        return _fetch_baby_summary_row(
            conn, firebase_uid, baby_profile_id, owner_only=False
        )
