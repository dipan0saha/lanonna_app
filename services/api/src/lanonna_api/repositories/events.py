from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.repositories.catalog_suggestions import (
    catalog_suggestion_claimed_on_table,
)


def list_events(
    baby_profile_id: uuid.UUID,
    *,
    month_start: datetime | None = None,
    month_end: datetime | None = None,
    upcoming_only: bool = False,
    now: datetime | None = None,
) -> list[dict[str, Any]]:
    clauses = ["e.baby_profile_id = %s"]
    params: list[Any] = [baby_profile_id]
    if month_start is not None and month_end is not None:
        clauses.append("e.starts_at >= %s AND e.starts_at < %s")
        params.extend([month_start, month_end])
    if upcoming_only:
        clauses.append("e.starts_at >= %s")
        from datetime import timezone

        params.append(now or datetime.now(timezone.utc))
    where = " AND ".join(clauses)
    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                e.id, e.title, e.description, e.starts_at, e.ends_at,
                e.location, e.video_call_url, e.cover_photo_id,
                e.catalog_suggestion_id,
                e.created_by_firebase_uid, e.created_at
            FROM events e
            WHERE {where}
            ORDER BY e.starts_at ASC
            """,
            tuple(params),
        ).fetchall()
    return [dict(r) for r in rows]


def get_event(baby_profile_id: uuid.UUID, event_id: uuid.UUID) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                e.id, e.title, e.description, e.starts_at, e.ends_at,
                e.location, e.video_call_url, e.cover_photo_id,
                e.catalog_suggestion_id,
                e.created_by_firebase_uid, e.created_at, e.updated_at
            FROM events e
            WHERE e.id = %s AND e.baby_profile_id = %s
            """,
            (event_id, baby_profile_id),
        ).fetchone()
    return dict(row) if row else None


def catalog_suggestion_claimed(
    baby_profile_id: uuid.UUID,
    catalog_suggestion_id: str,
) -> bool:
    return catalog_suggestion_claimed_on_table(
        "events", baby_profile_id, catalog_suggestion_id
    )


def create_event(
    baby_profile_id: uuid.UUID,
    created_by_firebase_uid: str,
    *,
    title: str,
    starts_at: datetime,
    ends_at: datetime | None,
    description: str | None,
    location: str | None,
    video_call_url: str | None,
    cover_photo_id: uuid.UUID | None,
    catalog_suggestion_id: str | None = None,
) -> dict[str, Any]:
    event_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO events (
                id, baby_profile_id, created_by_firebase_uid,
                title, starts_at, ends_at, description, location,
                video_call_url, cover_photo_id, catalog_suggestion_id
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, title, starts_at, ends_at, description, location,
                      video_call_url, cover_photo_id, catalog_suggestion_id,
                      created_at
            """,
            (
                event_id,
                baby_profile_id,
                created_by_firebase_uid,
                title.strip(),
                starts_at,
                ends_at,
                description,
                location,
                video_call_url,
                cover_photo_id,
                catalog_suggestion_id,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("create_event failed")
    return dict(row)


def update_event(
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any] | None:
    allowed = {
        "title",
        "starts_at",
        "ends_at",
        "description",
        "location",
        "video_call_url",
        "cover_photo_id",
    }
    set_parts = []
    values: list[Any] = []
    for key, val in fields.items():
        if key in allowed:
            set_parts.append(f"{key} = %s")
            values.append(val)
    if not set_parts:
        return get_event(baby_profile_id, event_id)
    set_parts.append("updated_at = now()")
    values.extend([event_id, baby_profile_id])
    with get_connection() as conn:
        row = conn.execute(
            f"""
            UPDATE events
            SET {", ".join(set_parts)}
            WHERE id = %s AND baby_profile_id = %s
            RETURNING id, title, starts_at, ends_at, description, location,
                      video_call_url, cover_photo_id, updated_at
            """,
            tuple(values),
        ).fetchone()
    return dict(row) if row else None


def delete_event(baby_profile_id: uuid.UUID, event_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            "DELETE FROM events WHERE id = %s AND baby_profile_id = %s",
            (event_id, baby_profile_id),
        )
    return cur.rowcount > 0


def upsert_rsvp(
    event_id: uuid.UUID,
    firebase_uid: str,
    status: str,
) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO event_rsvps (event_id, firebase_uid, status)
            VALUES (%s, %s, %s)
            ON CONFLICT (event_id, firebase_uid) DO UPDATE
              SET status = EXCLUDED.status, updated_at = now()
            RETURNING event_id, firebase_uid, status, updated_at
            """,
            (event_id, firebase_uid, status),
        ).fetchone()
    if row is None:
        raise RuntimeError("upsert_rsvp failed")
    return dict(row)


def get_caller_rsvp(event_id: uuid.UUID, firebase_uid: str) -> str | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT status FROM event_rsvps
            WHERE event_id = %s AND firebase_uid = %s
            """,
            (event_id, firebase_uid),
        ).fetchone()
    return row["status"] if row else None


def list_rsvps_for_event(event_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                r.firebase_uid,
                r.status,
                u.display_name,
                u.email
            FROM event_rsvps r
            JOIN app_users u ON u.firebase_uid = r.firebase_uid
            WHERE r.event_id = %s
            ORDER BY r.updated_at DESC
            """,
            (event_id,),
        ).fetchall()
    return [dict(row) for row in rows]


def rsvp_summary(event_id: uuid.UUID) -> dict[str, int]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT status, COUNT(*)::int AS cnt
            FROM event_rsvps
            WHERE event_id = %s
            GROUP BY status
            """,
            (event_id,),
        ).fetchall()
    out = {"going": 0, "maybe": 0, "cant_go": 0}
    for row in rows:
        out[row["status"]] = row["cnt"]
    return out


def list_event_comments(event_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                c.id, c.body, c.author_firebase_uid, c.created_at, c.updated_at,
                u.display_name AS author_display_name,
                u.email AS author_email
            FROM event_comments c
            JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
            WHERE c.event_id = %s AND c.deleted_at IS NULL
            ORDER BY c.created_at ASC
            """,
            (event_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def insert_event_comment(
    event_id: uuid.UUID,
    author_firebase_uid: str,
    body: str,
) -> dict[str, Any]:
    comment_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO event_comments (id, event_id, author_firebase_uid, body)
            VALUES (%s, %s, %s, %s)
            RETURNING id, body, author_firebase_uid, created_at
            """,
            (comment_id, event_id, author_firebase_uid, body.strip()),
        ).fetchone()
    if row is None:
        raise RuntimeError("insert_event_comment failed")
    return dict(row)


def update_event_comment(
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
    author_firebase_uid: str,
    body: str,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE event_comments
            SET body = %s, updated_at = now()
            WHERE id = %s AND event_id = %s
              AND author_firebase_uid = %s
              AND deleted_at IS NULL
            RETURNING id, body, created_at, updated_at
            """,
            (body.strip(), comment_id, event_id, author_firebase_uid),
        ).fetchone()
    return dict(row) if row else None


def get_event_comment(
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, body, author_firebase_uid, created_at, updated_at
            FROM event_comments
            WHERE id = %s AND event_id = %s AND deleted_at IS NULL
            """,
            (comment_id, event_id),
        ).fetchone()
    return dict(row) if row else None


def soft_delete_event_comment(
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            """
            UPDATE event_comments
            SET deleted_at = now(), updated_at = now()
            WHERE id = %s AND event_id = %s
              AND deleted_at IS NULL
            """,
            (comment_id, event_id),
        )
    return cur.rowcount > 0
