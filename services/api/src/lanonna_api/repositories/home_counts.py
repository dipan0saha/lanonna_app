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
