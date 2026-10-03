from __future__ import annotations

import uuid
from typing import Any, Literal

PhotoListSort = Literal["default", "recent", "favorites"]

from lanonna_api.db import get_connection


def get_photo_for_baby(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                p.id, p.baby_profile_id, p.uploader_firebase_uid,
                p.status, p.display_path, p.thumb_path, p.caption,
                p.content_type, p.created_at,
                u.display_name AS uploader_display_name,
                u.email AS uploader_email
            FROM photos p
            JOIN app_users u ON u.firebase_uid = p.uploader_firebase_uid
            WHERE p.id = %s AND p.baby_profile_id = %s
            """,
            (photo_id, baby_profile_id),
        ).fetchone()
    return dict(row) if row else None


def list_photos_for_baby(
    baby_profile_id: uuid.UUID,
    *,
    ready_only: bool,
    limit: int = 50,
    offset: int = 0,
    sort: PhotoListSort = "default",
) -> list[dict[str, Any]]:
    status_clause = "AND p.status = 'ready'" if ready_only else ""
    recent_clause = (
        "AND p.created_at >= now() - interval '30 days'" if sort == "recent" else ""
    )
    favorites_clause = (
        """
            AND (SELECT COUNT(*)::int FROM photo_squishes s WHERE s.photo_id = p.id) > 0
        """
        if sort == "favorites"
        else ""
    )
    if sort == "favorites":
        order_clause = "ORDER BY squish_count DESC, p.created_at DESC"
    else:
        order_clause = "ORDER BY p.created_at DESC"
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                p.id, p.status, p.caption, p.created_at, p.thumb_path,
                p.uploader_firebase_uid,
                u.display_name AS uploader_display_name,
                u.email AS uploader_email,
                (SELECT COUNT(*)::int FROM photo_squishes s WHERE s.photo_id = p.id) AS squish_count,
                (SELECT COUNT(*)::int FROM photo_comments c
                 WHERE c.photo_id = p.id AND c.deleted_at IS NULL) AS comment_count
            FROM photos p
            JOIN app_users u ON u.firebase_uid = p.uploader_firebase_uid
            WHERE p.baby_profile_id = %s
            {status_clause}
            {recent_clause}
            {favorites_clause}
            {order_clause}
            LIMIT %s OFFSET %s
            """,
            (baby_profile_id, limit, offset),
        ).fetchall()
    return [dict(r) for r in rows]


def update_photo_caption(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    caption: str | None,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE photos
            SET caption = %s, updated_at = now()
            WHERE id = %s AND baby_profile_id = %s
            RETURNING id, caption, status
            """,
            (caption, photo_id, baby_profile_id),
        ).fetchone()
    return dict(row) if row else None


def delete_photo(baby_profile_id: uuid.UUID, photo_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            """
            DELETE FROM photos
            WHERE id = %s AND baby_profile_id = %s
            """,
            (photo_id, baby_profile_id),
        )
    return cur.rowcount > 0


def squish_count(photo_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*)::int AS c FROM photo_squishes WHERE photo_id = %s",
            (photo_id,),
        ).fetchone()
    return row["c"] if row else 0


def caller_squished(photo_id: uuid.UUID, firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1 FROM photo_squishes
            WHERE photo_id = %s AND firebase_uid = %s
            """,
            (photo_id, firebase_uid),
        ).fetchone()
    return row is not None


def toggle_squish(photo_id: uuid.UUID, firebase_uid: str) -> bool:
    """Returns True if squish is now active."""
    with get_connection() as conn:
        existing = conn.execute(
            """
            SELECT 1 FROM photo_squishes
            WHERE photo_id = %s AND firebase_uid = %s
            """,
            (photo_id, firebase_uid),
        ).fetchone()
        if existing:
            conn.execute(
                """
                DELETE FROM photo_squishes
                WHERE photo_id = %s AND firebase_uid = %s
                """,
                (photo_id, firebase_uid),
            )
            return False
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (photo_id, firebase_uid),
        )
        return True


def list_photo_comments(photo_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                c.id, c.body, c.author_firebase_uid, c.created_at, c.updated_at,
                u.display_name AS author_display_name,
                u.email AS author_email
            FROM photo_comments c
            JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
            WHERE c.photo_id = %s AND c.deleted_at IS NULL
            ORDER BY c.created_at ASC
            """,
            (photo_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def insert_photo_comment(
    photo_id: uuid.UUID,
    author_firebase_uid: str,
    body: str,
) -> dict[str, Any]:
    comment_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO photo_comments (id, photo_id, author_firebase_uid, body)
            VALUES (%s, %s, %s, %s)
            RETURNING id, body, author_firebase_uid, created_at
            """,
            (comment_id, photo_id, author_firebase_uid, body.strip()),
        ).fetchone()
    if row is None:
        raise RuntimeError("insert_photo_comment failed")
    return dict(row)


def update_photo_comment(
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    author_firebase_uid: str,
    body: str,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE photo_comments
            SET body = %s, updated_at = now()
            WHERE id = %s AND photo_id = %s
              AND author_firebase_uid = %s
              AND deleted_at IS NULL
            RETURNING id, body, created_at, updated_at
            """,
            (body.strip(), comment_id, photo_id, author_firebase_uid),
        ).fetchone()
    return dict(row) if row else None


def soft_delete_photo_comment(
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    author_firebase_uid: str,
) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            """
            UPDATE photo_comments
            SET deleted_at = now(), updated_at = now()
            WHERE id = %s AND photo_id = %s
              AND author_firebase_uid = %s
              AND deleted_at IS NULL
            """,
            (comment_id, photo_id, author_firebase_uid),
        )
    return cur.rowcount > 0
