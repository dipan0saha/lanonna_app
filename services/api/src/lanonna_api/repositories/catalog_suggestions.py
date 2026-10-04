from __future__ import annotations

import uuid

from lanonna_api.db import get_connection

_ALLOWED_TABLES = frozenset({"events", "registry_items"})


def catalog_suggestion_claimed_on_table(
    table: str,
    baby_profile_id: uuid.UUID,
    catalog_suggestion_id: str,
) -> bool:
    if table not in _ALLOWED_TABLES:
        raise ValueError(f"Unsupported catalog table: {table}")
    with get_connection() as conn:
        row = conn.execute(
            f"""
            SELECT 1 FROM {table}
            WHERE baby_profile_id = %s AND catalog_suggestion_id = %s
            """,
            (baby_profile_id, catalog_suggestion_id),
        ).fetchone()
    return row is not None
