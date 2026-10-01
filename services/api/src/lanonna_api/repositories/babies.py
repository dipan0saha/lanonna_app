from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection


def list_babies_for_user(firebase_uid: str) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                b.id,
                b.name,
                b.gender,
                b.expected_birth_date,
                b.actual_birth_date,
                b.lifecycle_status,
                m.role,
                m.relationship_label
            FROM baby_memberships m
            JOIN baby_profiles b ON b.id = m.baby_profile_id
            WHERE m.firebase_uid = %s
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
            ORDER BY b.created_at ASC
            """,
            (firebase_uid,),
        ).fetchall()
    return [dict(row) for row in rows]


def create_baby_with_owner_membership(
    firebase_uid: str,
    name: str,
    gender: str | None,
    expected_birth_date,
    actual_birth_date,
    lifecycle_status: str,
) -> dict[str, Any]:
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        baby = conn.execute(
            """
            INSERT INTO baby_profiles (
                id, name, gender, expected_birth_date,
                actual_birth_date, lifecycle_status
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, name, gender, expected_birth_date,
                      actual_birth_date, lifecycle_status, created_at
            """,
            (
                baby_id,
                name,
                gender,
                expected_birth_date,
                actual_birth_date,
                lifecycle_status,
            ),
        ).fetchone()
        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role
            )
            VALUES (%s, %s, 'owner')
            """,
            (baby_id, firebase_uid),
        )
    if baby is None:
        raise RuntimeError("create_baby returned no row")
    result = dict(baby)
    result["role"] = "owner"
    result["relationship_label"] = None
    return result


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
            RETURNING b.id, b.name, b.gender, b.expected_birth_date,
                      b.actual_birth_date, b.lifecycle_status
            """,
            values,
        ).fetchone()
    if row is None:
        return None
    result = dict(row)
    result["role"] = "owner"
    result["relationship_label"] = None
    return result


def get_baby_for_owner(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                b.id, b.name, b.gender, b.expected_birth_date,
                b.actual_birth_date, b.lifecycle_status,
                m.role, m.relationship_label
            FROM baby_profiles b
            JOIN baby_memberships m ON m.baby_profile_id = b.id
            WHERE b.id = %s
              AND m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return dict(row) if row else None


def get_baby_membership(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                b.id, b.name, b.gender, b.expected_birth_date,
                b.actual_birth_date, b.lifecycle_status,
                m.role, m.relationship_label
            FROM baby_profiles b
            JOIN baby_memberships m ON m.baby_profile_id = b.id
            WHERE b.id = %s
              AND m.firebase_uid = %s
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
            """,
            (baby_profile_id, firebase_uid),
        ).fetchone()
    return dict(row) if row else None
