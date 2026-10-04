from __future__ import annotations

import re

_CATALOG_SUGGESTION_ID = re.compile(r"^[a-z][a-z0-9_]{0,63}$")


def normalize_catalog_suggestion_id(raw: str | None) -> str | None:
    if raw is None:
        return None
    value = raw.strip()
    if not value:
        return None
    if not _CATALOG_SUGGESTION_ID.fullmatch(value):
        raise ValueError("Invalid catalog suggestion id.")
    return value
