from __future__ import annotations

from typing import Any

from lanonna_api.db import get_connection


def count_engagement_for_user(firebase_uid: str) -> dict[str, int]:
    with get_connection() as conn:
        photo_squishes = conn.execute(
            "SELECT COUNT(*)::int AS n FROM photo_squishes WHERE firebase_uid = %s",
            (firebase_uid,),
        ).fetchone()
        announcement_squishes = conn.execute(
            "SELECT COUNT(*)::int AS n FROM announcement_squishes WHERE firebase_uid = %s",
            (firebase_uid,),
        ).fetchone()
        events_attended = conn.execute(
            """
            SELECT COUNT(*)::int AS n FROM event_rsvps
            WHERE firebase_uid = %s AND status = 'going'
            """,
            (firebase_uid,),
        ).fetchone()
        items_bought = conn.execute(
            """
            SELECT COUNT(*)::int AS n FROM registry_purchases
            WHERE purchased_by_firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchone()
        photo_comments = conn.execute(
            """
            SELECT COUNT(*)::int AS n FROM photo_comments
            WHERE author_firebase_uid = %s AND deleted_at IS NULL
            """,
            (firebase_uid,),
        ).fetchone()
        event_comments = conn.execute(
            """
            SELECT COUNT(*)::int AS n FROM event_comments
            WHERE author_firebase_uid = %s AND deleted_at IS NULL
            """,
            (firebase_uid,),
        ).fetchone()
        announcement_comments = conn.execute(
            """
            SELECT COUNT(*)::int AS n FROM announcement_comments
            WHERE author_firebase_uid = %s AND deleted_at IS NULL
            """,
            (firebase_uid,),
        ).fetchone()

    photos_squished = int(photo_squishes["n"] or 0) + int(announcement_squishes["n"] or 0)
    comments = (
        int(photo_comments["n"] or 0)
        + int(event_comments["n"] or 0)
        + int(announcement_comments["n"] or 0)
    )
    return {
        "photos_squished": photos_squished,
        "events_attended": int(events_attended["n"] or 0),
        "items_bought": int(items_bought["n"] or 0),
        "comments": comments,
    }


def storage_usage_for_owner_babies(firebase_uid: str) -> dict[str, Any] | None:
    """Bytes used by ready display photos on babies the user owns."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COALESCE(SUM(p.byte_length), 0)::bigint AS used_bytes
            FROM photos p
            JOIN baby_memberships m ON m.baby_profile_id = p.baby_profile_id
            WHERE m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND p.status = 'ready'
              AND p.byte_length IS NOT NULL
            """,
            (firebase_uid,),
        ).fetchone()
    if row is None:
        return None
    used = int(row["used_bytes"] or 0)
    quota_bytes = 15 * 1024 * 1024 * 1024  # 15 GB free tier (prototype)
    return {
        "used_bytes": used,
        "quota_bytes": quota_bytes,
    }
