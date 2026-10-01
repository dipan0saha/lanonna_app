from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from lanonna_api.db import get_connection


def get_announcement(baby_profile_id: uuid.UUID) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT a.*,
                   (SELECT COUNT(*)::int FROM announcement_squishes s
                    WHERE s.announcement_id = a.id) AS squish_count,
                   (SELECT COUNT(*)::int FROM announcement_comments c
                    WHERE c.announcement_id = a.id AND c.deleted_at IS NULL) AS comment_count
            FROM birth_announcements a
            WHERE a.baby_profile_id = %s
            """,
            (baby_profile_id,),
        ).fetchone()
    return dict(row) if row else None


def upsert_announcement(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    *,
    first_name: str | None,
    last_name: str | None,
    gender: str | None,
    birth_date: date | None,
    birth_time: str | None,
    weight_text: str | None,
    length_text: str | None,
    photo_id: uuid.UUID | None,
) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO birth_announcements (
                baby_profile_id, created_by_firebase_uid,
                first_name, last_name, gender, birth_date, birth_time,
                weight_text, length_text, photo_id
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (baby_profile_id) DO UPDATE SET
                first_name = EXCLUDED.first_name,
                last_name = EXCLUDED.last_name,
                gender = EXCLUDED.gender,
                birth_date = EXCLUDED.birth_date,
                birth_time = EXCLUDED.birth_time,
                weight_text = EXCLUDED.weight_text,
                length_text = EXCLUDED.length_text,
                photo_id = EXCLUDED.photo_id,
                updated_at = now()
            RETURNING id
            """,
            (
                baby_profile_id,
                firebase_uid,
                first_name,
                last_name,
                gender,
                birth_date,
                birth_time,
                weight_text,
                length_text,
                photo_id,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("upsert_announcement failed")
    ann = get_announcement(baby_profile_id)
    assert ann is not None
    return ann


def toggle_squish(announcement_id: uuid.UUID, firebase_uid: str) -> bool:
    with get_connection() as conn:
        existing = conn.execute(
            """
            SELECT 1 FROM announcement_squishes
            WHERE announcement_id = %s AND firebase_uid = %s
            """,
            (announcement_id, firebase_uid),
        ).fetchone()
        if existing:
            conn.execute(
                """
                DELETE FROM announcement_squishes
                WHERE announcement_id = %s AND firebase_uid = %s
                """,
                (announcement_id, firebase_uid),
            )
            return False
        conn.execute(
            """
            INSERT INTO announcement_squishes (announcement_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (announcement_id, firebase_uid),
        )
        return True


def list_comments(announcement_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT c.id, c.body, c.created_at, c.author_firebase_uid,
                   COALESCE(u.display_name, 'Family member') AS author_display_name
            FROM announcement_comments c
            JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
            WHERE c.announcement_id = %s AND c.deleted_at IS NULL
            ORDER BY c.created_at ASC
            """,
            (announcement_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def add_comment(
    announcement_id: uuid.UUID,
    firebase_uid: str,
    body: str,
) -> dict[str, Any]:
    comment_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO announcement_comments (
                id, announcement_id, author_firebase_uid, body
            )
            VALUES (%s, %s, %s, %s)
            RETURNING id, body, created_at, author_firebase_uid
            """,
            (comment_id, announcement_id, firebase_uid, body.strip()),
        ).fetchone()
    if row is None:
        raise RuntimeError("add_comment failed")
    return dict(row)
