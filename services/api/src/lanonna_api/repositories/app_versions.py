from __future__ import annotations

from typing import Any

from lanonna_api.db import get_connection


def get_app_version_requirement(platform: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT platform, minimum_version, store_url, updated_at
            FROM app_versions
            WHERE platform = %s
            """,
            (platform,),
        ).fetchone()
    return dict(row) if row else None
