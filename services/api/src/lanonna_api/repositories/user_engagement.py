from __future__ import annotations

from typing import Any

from lanonna_api.db import get_connection


def count_engagement_for_user(firebase_uid: str) -> dict[str, int]:
    """Every My Account engagement count in one round trip."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                (SELECT COUNT(*)::int FROM photo_squishes
                 WHERE firebase_uid = %(uid)s) AS photo_squishes,
                (SELECT COUNT(*)::int FROM announcement_squishes
                 WHERE firebase_uid = %(uid)s) AS announcement_squishes,
                (SELECT COUNT(*)::int FROM event_rsvps
                 WHERE firebase_uid = %(uid)s AND status = 'going') AS events_attended,
                (SELECT COUNT(*)::int FROM registry_purchases
                 WHERE purchased_by_firebase_uid = %(uid)s) AS items_bought,
                (SELECT COUNT(*)::int FROM photo_comments
                 WHERE author_firebase_uid = %(uid)s AND deleted_at IS NULL) AS photo_comments,
                (SELECT COUNT(*)::int FROM event_comments
                 WHERE author_firebase_uid = %(uid)s AND deleted_at IS NULL) AS event_comments,
                (SELECT COUNT(*)::int FROM announcement_comments
                 WHERE author_firebase_uid = %(uid)s AND deleted_at IS NULL) AS announcement_comments
            """,
            {"uid": firebase_uid},
        ).fetchone()

    photos_squished = int(row["photo_squishes"] or 0) + int(row["announcement_squishes"] or 0)
    comments = (
        int(row["photo_comments"] or 0)
        + int(row["event_comments"] or 0)
        + int(row["announcement_comments"] or 0)
    )
    return {
        "photos_squished": photos_squished,
        "events_attended": int(row["events_attended"] or 0),
        "items_bought": int(row["items_bought"] or 0),
        "comments": comments,
    }


def storage_usage_for_owner_babies(firebase_uid: str) -> dict[str, Any] | None:
    """Bytes used by ready display photos on babies the user owns."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COALESCE(SUM(p.byte_length), 0)::bigint AS used_bytes
            FROM photos p
            JOIN baby_profiles b ON b.id = p.baby_profile_id AND b.deleted_at IS NULL
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
