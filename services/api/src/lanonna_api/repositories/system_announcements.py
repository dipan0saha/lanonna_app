from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from lanonna_api.db import get_connection


def list_active_for_user(
    firebase_uid: str,
    *,
    membership_role: str,
) -> list[dict[str, Any]]:
    role = membership_role if membership_role in ("owner", "follower") else "follower"
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT a.id, a.title, a.body, a.cta_label, a.cta_deep_link, a.priority
            FROM system_announcements a
            WHERE a.deleted_at IS NULL
              AND a.starts_at <= now()
              AND (a.ends_at IS NULL OR a.ends_at > now())
              AND (
                a.target_audience = 'all'
                OR (a.target_audience = 'owners' AND %s = 'owner')
                OR (a.target_audience = 'followers' AND %s = 'follower')
              )
              AND NOT EXISTS (
                SELECT 1 FROM announcement_dismissals d
                WHERE d.announcement_id = a.id
                  AND d.firebase_uid = %s
              )
            ORDER BY a.priority DESC, a.starts_at DESC
            LIMIT 5
            """,
            (role, role, firebase_uid),
        ).fetchall()
    return [dict(r) for r in rows]


def dismiss_announcement(announcement_id: uuid.UUID, firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT 1 FROM system_announcements WHERE id = %s AND deleted_at IS NULL",
            (announcement_id,),
        ).fetchone()
        if row is None:
            return False
        conn.execute(
            """
            INSERT INTO announcement_dismissals (announcement_id, firebase_uid)
            VALUES (%s, %s)
            ON CONFLICT (announcement_id, firebase_uid) DO NOTHING
            """,
            (announcement_id, firebase_uid),
        )
    return True


def admin_list_all() -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT id, title, body, cta_label, cta_deep_link,
                   starts_at, ends_at, target_audience, priority,
                   deleted_at, created_at, updated_at
            FROM system_announcements
            ORDER BY created_at DESC
            LIMIT 100
            """
        ).fetchall()
    return [dict(r) for r in rows]


def admin_create(
    *,
    title: str,
    body: str,
    cta_label: str | None,
    cta_deep_link: str | None,
    starts_at: datetime | None,
    ends_at: datetime | None,
    target_audience: str,
    priority: int,
) -> dict[str, Any]:
    ann_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO system_announcements (
                id, title, body, cta_label, cta_deep_link,
                starts_at, ends_at, target_audience, priority
            )
            VALUES (%s, %s, %s, %s, %s, COALESCE(%s, now()), %s, %s, %s)
            RETURNING id, title, body, starts_at, ends_at, target_audience, priority
            """,
            (
                ann_id,
                title,
                body,
                cta_label,
                cta_deep_link,
                starts_at,
                ends_at,
                target_audience,
                priority,
            ),
        ).fetchone()
    return dict(row) if row else {}


def admin_update(announcement_id: uuid.UUID, fields: dict[str, Any]) -> dict[str, Any] | None:
    allowed = {
        "title",
        "body",
        "cta_label",
        "cta_deep_link",
        "starts_at",
        "ends_at",
        "target_audience",
        "priority",
    }
    updates = {k: v for k, v in fields.items() if k in allowed and v is not None}
    if not updates:
        return admin_get(announcement_id)
    set_parts = [f"{k} = %s" for k in updates]
    values = list(updates.values()) + [announcement_id]
    with get_connection() as conn:
        row = conn.execute(
            f"""
            UPDATE system_announcements
            SET {", ".join(set_parts)}, updated_at = now()
            WHERE id = %s AND deleted_at IS NULL
            RETURNING id, title, body, starts_at, ends_at, target_audience, priority
            """,
            values,
        ).fetchone()
    return dict(row) if row else None


def admin_get(announcement_id: uuid.UUID) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, title, body, cta_label, cta_deep_link,
                   starts_at, ends_at, target_audience, priority, deleted_at
            FROM system_announcements
            WHERE id = %s
            """,
            (announcement_id,),
        ).fetchone()
    return dict(row) if row else None


def admin_soft_delete(announcement_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE system_announcements
            SET deleted_at = now(), updated_at = now()
            WHERE id = %s AND deleted_at IS NULL
            RETURNING id
            """,
            (announcement_id,),
        ).fetchone()
    return row is not None
