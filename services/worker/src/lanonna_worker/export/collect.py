"""Load one baby's rows for export. SQL only; shaping is in document.py."""

from __future__ import annotations

import uuid
from typing import Any

from lanonna_worker.export.coverage import COVERED_TABLES

ACTIVITY_EXPORT_MAX_ROWS = 500


def _rows(conn: Any, sql: str, params: tuple[Any, ...]) -> list[dict[str, Any]]:
    return [dict(row) for row in conn.execute(sql, params).fetchall()]


def _one(conn: Any, sql: str, params: tuple[Any, ...]) -> dict[str, Any] | None:
    row = conn.execute(sql, params).fetchone()
    return dict(row) if row else None


def assert_export_owner(conn: Any, baby_id: uuid.UUID, requester_uid: str) -> None:
    row = _one(
        conn,
        """
        SELECT 1 AS ok
        FROM baby_memberships
        WHERE baby_profile_id = %s
          AND firebase_uid = %s
          AND role = 'owner'
          AND removed_at IS NULL
        """,
        (baby_id, requester_uid),
    )
    if row is None:
        raise PermissionError("Owner access required for this baby profile.")


def collect_baby_export(
    conn: Any,
    baby_id: uuid.UUID,
    requester_uid: str,
) -> dict[str, Any]:
    """Read every covered table for one baby the requester still owns.

    Photo tags are limited to babies the requester is an active member of,
    the same read scope as ``repositories/photo_tags.py``.
    """
    assert_export_owner(conn, baby_id, requester_uid)
    baby = _one(
        conn,
        """
        SELECT id, name, expected_birth_date, actual_birth_date, gender,
               lifecycle_status, avatar_url, created_at, updated_at, deleted_at,
               created_by_firebase_uid,
               registry_shipping_line1, registry_shipping_line2,
               registry_shipping_city, registry_shipping_region,
               registry_shipping_postal_code, registry_shipping_country_code
        FROM baby_profiles
        WHERE id = %s
        """,
        (baby_id,),
    )
    if baby is None:
        raise LookupError("Baby profile not found.")

    memberships = _rows(
        conn,
        """
        SELECT m.firebase_uid, m.role, m.relationship_label, m.joined_via,
               m.created_at, m.removed_at,
               u.display_name, u.email
        FROM baby_memberships m
        JOIN app_users u ON u.firebase_uid = m.firebase_uid
        WHERE m.baby_profile_id = %s
        ORDER BY m.created_at, m.firebase_uid
        """,
        (baby_id,),
    )
    photos = _rows(
        conn,
        """
        SELECT id, uploader_firebase_uid, caption, status, display_path,
               thumb_path, content_type, byte_length, created_at, updated_at
        FROM photos
        WHERE baby_profile_id = %s
        ORDER BY created_at, id
        """,
        (baby_id,),
    )
    photo_comments = _rows(
        conn,
        """
        SELECT c.id, c.photo_id, c.author_firebase_uid, c.body,
               c.created_at, c.updated_at, u.display_name AS author_display_name
        FROM photo_comments c
        JOIN photos p ON p.id = c.photo_id
        LEFT JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
        WHERE p.baby_profile_id = %s
          AND c.deleted_at IS NULL
        ORDER BY c.created_at, c.id
        """,
        (baby_id,),
    )
    photo_squishes = _rows(
        conn,
        """
        SELECT s.photo_id, s.firebase_uid, s.created_at, u.display_name
        FROM photo_squishes s
        JOIN photos p ON p.id = s.photo_id
        LEFT JOIN app_users u ON u.firebase_uid = s.firebase_uid
        WHERE p.baby_profile_id = %s
        ORDER BY s.created_at, s.firebase_uid
        """,
        (baby_id,),
    )
    photo_tags = _rows(
        conn,
        """
        SELECT t.photo_id, b.id AS tagged_baby_profile_id, b.name
        FROM photo_baby_tags t
        JOIN photos p ON p.id = t.photo_id AND p.baby_profile_id = %s
        JOIN baby_profiles b
          ON b.id = t.tagged_baby_profile_id
         AND b.deleted_at IS NULL
        JOIN baby_memberships m
          ON m.baby_profile_id = t.tagged_baby_profile_id
         AND m.firebase_uid = %s
         AND m.removed_at IS NULL
        ORDER BY b.name, b.id
        """,
        (baby_id, requester_uid),
    )
    events = _rows(
        conn,
        """
        SELECT id, created_by_firebase_uid, title, starts_at, ends_at,
               description, location, video_call_url, cover_photo_id,
               catalog_suggestion_id, created_at, updated_at
        FROM events
        WHERE baby_profile_id = %s
        ORDER BY starts_at, id
        """,
        (baby_id,),
    )
    event_rsvps = _rows(
        conn,
        """
        SELECT r.event_id, r.firebase_uid, r.status, r.created_at, r.updated_at,
               u.display_name
        FROM event_rsvps r
        JOIN events e ON e.id = r.event_id
        LEFT JOIN app_users u ON u.firebase_uid = r.firebase_uid
        WHERE e.baby_profile_id = %s
        ORDER BY r.updated_at, r.firebase_uid
        """,
        (baby_id,),
    )
    event_comments = _rows(
        conn,
        """
        SELECT c.id, c.event_id, c.author_firebase_uid, c.body,
               c.created_at, c.updated_at, u.display_name AS author_display_name
        FROM event_comments c
        JOIN events e ON e.id = c.event_id
        LEFT JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
        WHERE e.baby_profile_id = %s
          AND c.deleted_at IS NULL
        ORDER BY c.created_at, c.id
        """,
        (baby_id,),
    )
    registry_items = _rows(
        conn,
        """
        SELECT id, created_by_firebase_uid, name, priority, description,
               product_url, catalog_suggestion_id, created_at, updated_at
        FROM registry_items
        WHERE baby_profile_id = %s
        ORDER BY created_at, id
        """,
        (baby_id,),
    )
    purchases = _rows(
        conn,
        """
        SELECT rp.id, rp.registry_item_id, rp.purchased_by_firebase_uid,
               rp.created_at, u.display_name AS purchaser_display_name
        FROM registry_purchases rp
        JOIN registry_items i ON i.id = rp.registry_item_id
        LEFT JOIN app_users u ON u.firebase_uid = rp.purchased_by_firebase_uid
        WHERE i.baby_profile_id = %s
        ORDER BY rp.created_at, rp.id
        """,
        (baby_id,),
    )
    name_suggestions = _rows(
        conn,
        """
        SELECT n.id, n.suggested_by_firebase_uid, n.suggested_name, n.gender,
               n.created_at, u.display_name AS suggester_display_name
        FROM name_suggestions n
        LEFT JOIN app_users u ON u.firebase_uid = n.suggested_by_firebase_uid
        WHERE n.baby_profile_id = %s
        ORDER BY n.created_at, n.id
        """,
        (baby_id,),
    )
    name_likes = _rows(
        conn,
        """
        SELECT l.name_suggestion_id, l.firebase_uid, l.created_at, u.display_name
        FROM name_suggestion_likes l
        JOIN name_suggestions n ON n.id = l.name_suggestion_id
        LEFT JOIN app_users u ON u.firebase_uid = l.firebase_uid
        WHERE n.baby_profile_id = %s
        ORDER BY l.created_at, l.firebase_uid
        """,
        (baby_id,),
    )
    votes = _rows(
        conn,
        """
        SELECT v.vote_type, v.gender_value, v.predicted_birth_date,
               v.is_anonymous, v.firebase_uid, v.created_at, v.updated_at,
               u.display_name
        FROM votes v
        LEFT JOIN app_users u ON u.firebase_uid = v.firebase_uid
        WHERE v.baby_profile_id = %s
        ORDER BY v.created_at, v.vote_type, v.firebase_uid
        """,
        (baby_id,),
    )
    announcement = _one(
        conn,
        """
        SELECT a.id, a.photo_id, a.first_name, a.last_name, a.gender,
               a.birth_date, a.birth_time, a.weight_text, a.length_text,
               a.created_by_firebase_uid, a.created_at, a.updated_at,
               u.display_name AS author_display_name
        FROM birth_announcements a
        LEFT JOIN app_users u ON u.firebase_uid = a.created_by_firebase_uid
        WHERE a.baby_profile_id = %s
        """,
        (baby_id,),
    )
    announcement_comments: list[dict[str, Any]] = []
    announcement_squishes: list[dict[str, Any]] = []
    if announcement is not None:
        announcement_comments = _rows(
            conn,
            """
            SELECT c.id, c.author_firebase_uid, c.body, c.created_at, c.updated_at,
                   u.display_name AS author_display_name
            FROM announcement_comments c
            LEFT JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
            WHERE c.announcement_id = %s
              AND c.deleted_at IS NULL
            ORDER BY c.created_at, c.id
            """,
            (announcement["id"],),
        )
        announcement_squishes = _rows(
            conn,
            """
            SELECT s.firebase_uid, s.created_at, u.display_name
            FROM announcement_squishes s
            LEFT JOIN app_users u ON u.firebase_uid = s.firebase_uid
            WHERE s.announcement_id = %s
            ORDER BY s.created_at, s.firebase_uid
            """,
            (announcement["id"],),
        )
    invitations = _rows(
        conn,
        """
        SELECT i.id, i.invitee_email, i.role, i.relationship_label, i.status,
               i.expires_at, i.created_at, i.inviter_firebase_uid,
               i.token_hash, i.email_invite_token,
               u.display_name AS inviter_display_name
        FROM invitations i
        LEFT JOIN app_users u ON u.firebase_uid = i.inviter_firebase_uid
        WHERE i.baby_profile_id = %s
        ORDER BY i.created_at, i.id
        """,
        (baby_id,),
    )
    activity_count = _one(
        conn,
        """
        SELECT COUNT(*)::int AS n
        FROM activity_events
        WHERE baby_profile_id = %s
        """,
        (baby_id,),
    )
    activity_total = int(activity_count["n"]) if activity_count else 0
    activity = _rows(
        conn,
        """
        SELECT e.id, e.actor_firebase_uid, e.event_type, e.summary, e.params, e.payload,
               e.created_at, u.display_name AS actor_display_name
        FROM activity_events e
        LEFT JOIN app_users u ON u.firebase_uid = e.actor_firebase_uid
        WHERE e.baby_profile_id = %s
        ORDER BY e.created_at DESC, e.id DESC
        LIMIT %s
        """,
        (baby_id, ACTIVITY_EXPORT_MAX_ROWS),
    )
    return {
        "covered_tables": sorted(COVERED_TABLES),
        "baby": baby,
        "memberships": memberships,
        "photos": photos,
        "photo_comments": photo_comments,
        "photo_squishes": photo_squishes,
        "photo_tags": photo_tags,
        "events": events,
        "event_rsvps": event_rsvps,
        "event_comments": event_comments,
        "registry_items": registry_items,
        "purchases": purchases,
        "name_suggestions": name_suggestions,
        "name_likes": name_likes,
        "votes": votes,
        "announcement": announcement,
        "announcement_comments": announcement_comments,
        "announcement_squishes": announcement_squishes,
        "invitations": invitations,
        "activity": activity,
        "activity_total": activity_total,
    }
