"""SQL LIMIT/OFFSET clause shared by list repositories."""

from __future__ import annotations

from typing import Any


def limit_offset_clause(limit: int | None, offset: int) -> tuple[str, tuple[Any, ...]]:
    """Return ``("LIMIT %s OFFSET %s", (limit, offset))``, or no clause for ``limit=None``."""
    if limit is None:
        return "", ()
    return "LIMIT %s OFFSET %s", (limit, offset)
