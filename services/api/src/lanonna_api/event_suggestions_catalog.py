"""Calendar event suggestion catalog (same JSON as the mobile app assets)."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

_CATALOG_PATH = (
    Path(__file__).resolve().parents[4]
    / "apps/mobile/assets/calendar/event_suggestions.json"
)


@lru_cache(maxsize=1)
def event_catalog_titles() -> dict[str, str]:
    data = json.loads(_CATALOG_PATH.read_text(encoding="utf-8"))
    titles: dict[str, str] = {}
    for rows in data.values():
        for row in rows:
            titles[row["id"]] = row["title"]
    return titles


def canonical_event_title(catalog_suggestion_id: str) -> str | None:
    return event_catalog_titles().get(catalog_suggestion_id)


def resolve_event_title(title: str, catalog_suggestion_id: str | None) -> str:
    """Catalog-backed events always store the JSON title."""
    if catalog_suggestion_id is None:
        return title
    canonical = canonical_event_title(catalog_suggestion_id)
    return canonical if canonical is not None else title
