from __future__ import annotations

import uuid

from lanonna_api.db import get_connection


def count_photos_for_baby(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM photos
            WHERE baby_profile_id = %s AND deleted_at IS NULL
            """,
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0


def count_open_registry_items(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM registry_items r
            LEFT JOIN registry_purchases p ON p.registry_item_id = r.id
            WHERE r.baby_profile_id = %s AND p.id IS NULL
            """,
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0


def count_registry_items(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*)::int AS count FROM registry_items WHERE baby_profile_id = %s",
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0


def count_events(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*)::int AS count FROM events WHERE baby_profile_id = %s",
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0


def count_sent_invitations(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM invitations
            WHERE baby_profile_id = %s
            """,
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0


def list_new_followers(
    baby_profile_id: uuid.UUID,
    since_days: int = 30,
    limit: int = 5,
) -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                m.firebase_uid,
                m.created_at AS joined_at,
                COALESCE(u.display_name, u.email, 'Family member') AS display_name
            FROM baby_memberships m
            JOIN app_users u ON u.firebase_uid = m.firebase_uid
            WHERE m.baby_profile_id = %s
              AND m.role = 'follower'
              AND m.removed_at IS NULL
              AND m.created_at >= now() - make_interval(days => %s)
            ORDER BY m.created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, since_days, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def count_follower_memberships(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM baby_memberships
            WHERE baby_profile_id = %s
              AND role = 'follower'
              AND removed_at IS NULL
            """,
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0
