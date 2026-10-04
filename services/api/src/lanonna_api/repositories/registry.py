from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.repositories.catalog_suggestions import (
    catalog_suggestion_claimed_on_table,
)


def get_shipping_address(baby_profile_id: uuid.UUID) -> str | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT registry_shipping_address
            FROM baby_profiles
            WHERE id = %s AND deleted_at IS NULL
            """,
            (baby_profile_id,),
        ).fetchone()
    return row["registry_shipping_address"] if row else None


def update_shipping_address(baby_profile_id: uuid.UUID, address: str | None) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE baby_profiles
            SET registry_shipping_address = %s, updated_at = now()
            WHERE id = %s AND deleted_at IS NULL
            """,
            (address, baby_profile_id),
        )


def list_open_registry_highlights(
    baby_profile_id: uuid.UUID,
    limit: int = 3,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT i.id, i.name, i.priority
            FROM registry_items i
            LEFT JOIN registry_purchases p ON p.registry_item_id = i.id
            WHERE i.baby_profile_id = %s AND p.id IS NULL
            ORDER BY i.priority DESC, i.created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def list_recent_registry_purchases(
    baby_profile_id: uuid.UUID,
    since_days: int = 15,
    limit: int = 5,
) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                i.id AS item_id,
                i.name AS item_name,
                p.created_at AS purchased_at,
                p.purchased_by_firebase_uid,
                u.display_name AS purchaser_display_name
            FROM registry_purchases p
            JOIN registry_items i ON i.id = p.registry_item_id
            LEFT JOIN app_users u ON u.firebase_uid = p.purchased_by_firebase_uid
            WHERE i.baby_profile_id = %s
              AND p.created_at >= now() - make_interval(days => %s)
            ORDER BY p.created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, since_days, limit),
        ).fetchall()
    return [dict(r) for r in rows]


def list_registry_items(baby_profile_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                i.id, i.name, i.description, i.product_url, i.priority,
                i.catalog_suggestion_id,
                i.created_at, i.created_by_firebase_uid,
                p.id AS purchase_id,
                p.purchased_by_firebase_uid,
                p.created_at AS purchased_at,
                u.display_name AS purchaser_display_name,
                u.email AS purchaser_email
            FROM registry_items i
            LEFT JOIN registry_purchases p ON p.registry_item_id = i.id
            LEFT JOIN app_users u ON u.firebase_uid = p.purchased_by_firebase_uid
            WHERE i.baby_profile_id = %s
            ORDER BY i.priority DESC, i.created_at DESC
            """,
            (baby_profile_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def get_registry_item(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT
                i.id, i.name, i.description, i.product_url, i.priority,
                i.catalog_suggestion_id,
                i.baby_profile_id, i.created_by_firebase_uid,
                p.id AS purchase_id,
                p.purchased_by_firebase_uid,
                p.created_at AS purchased_at
            FROM registry_items i
            LEFT JOIN registry_purchases p ON p.registry_item_id = i.id
            WHERE i.id = %s AND i.baby_profile_id = %s
            """,
            (item_id, baby_profile_id),
        ).fetchone()
    return dict(row) if row else None


def catalog_suggestion_claimed(
    baby_profile_id: uuid.UUID,
    catalog_suggestion_id: str,
) -> bool:
    return catalog_suggestion_claimed_on_table(
        "registry_items", baby_profile_id, catalog_suggestion_id
    )


def create_registry_item(
    baby_profile_id: uuid.UUID,
    created_by_firebase_uid: str,
    *,
    name: str,
    description: str | None,
    product_url: str | None,
    priority: int,
    catalog_suggestion_id: str | None = None,
) -> dict[str, Any]:
    item_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO registry_items (
                id, baby_profile_id, created_by_firebase_uid,
                name, description, product_url, priority, catalog_suggestion_id
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, name, description, product_url, priority,
                catalog_suggestion_id, created_at
            """,
            (
                item_id,
                baby_profile_id,
                created_by_firebase_uid,
                name.strip(),
                description,
                product_url,
                priority,
                catalog_suggestion_id,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("create_registry_item failed")
    return dict(row)


def update_registry_item(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any] | None:
    allowed = {"name", "description", "product_url", "priority"}
    set_parts = []
    values: list[Any] = []
    for key, val in fields.items():
        if key in allowed:
            set_parts.append(f"{key} = %s")
            values.append(val)
    if not set_parts:
        return get_registry_item(baby_profile_id, item_id)
    set_parts.append("updated_at = now()")
    values.extend([item_id, baby_profile_id])
    with get_connection() as conn:
        row = conn.execute(
            f"""
            UPDATE registry_items
            SET {", ".join(set_parts)}
            WHERE id = %s AND baby_profile_id = %s
            RETURNING id, name, description, product_url, priority
            """,
            tuple(values),
        ).fetchone()
    return dict(row) if row else None


def delete_registry_item(baby_profile_id: uuid.UUID, item_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            "DELETE FROM registry_items WHERE id = %s AND baby_profile_id = %s",
            (item_id, baby_profile_id),
        )
    return cur.rowcount > 0


def item_has_purchase(item_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT 1 FROM registry_purchases WHERE registry_item_id = %s",
            (item_id,),
        ).fetchone()
    return row is not None


def create_purchase(item_id: uuid.UUID, firebase_uid: str) -> dict[str, Any]:
    purchase_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO registry_purchases (
                id, registry_item_id, purchased_by_firebase_uid
            )
            VALUES (%s, %s, %s)
            RETURNING id, registry_item_id, purchased_by_firebase_uid, created_at
            """,
            (purchase_id, item_id, firebase_uid),
        ).fetchone()
    if row is None:
        raise RuntimeError("create_purchase failed")
    return dict(row)


def delete_purchase(item_id: uuid.UUID) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            "DELETE FROM registry_purchases WHERE registry_item_id = %s",
            (item_id,),
        )
    return cur.rowcount > 0


def get_purchase(item_id: uuid.UUID) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, registry_item_id, purchased_by_firebase_uid, created_at
            FROM registry_purchases
            WHERE registry_item_id = %s
            """,
            (item_id,),
        ).fetchone()
    return dict(row) if row else None
