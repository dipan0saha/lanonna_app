"""Event catalog JSON titles match API helpers and first-moment presets."""

from pathlib import Path

from lanonna_api import first_moment_presets as presets
from lanonna_api.event_suggestions_catalog import (
    canonical_event_title,
    event_catalog_titles,
    resolve_event_title,
)

_ASSETS = Path(__file__).resolve().parents[3] / "apps/mobile/assets"


def test_event_catalog_titles_match_json():
    import json

    data = json.loads(
        (_ASSETS / "calendar/event_suggestions.json").read_text(encoding="utf-8")
    )
    expected: dict[str, str] = {}
    for rows in data.values():
        for row in rows:
            expected[row["id"]] = row["title"]
    assert event_catalog_titles() == expected


def test_first_moment_event_presets_match_catalog_titles():
    catalog = event_catalog_titles()
    for preset in presets.EXPECTING_EVENTS + presets.BORN_EVENTS:
        if preset.id in catalog:
            assert preset.label == catalog[preset.id]


def test_resolve_event_title_uses_catalog_when_id_known():
    assert (
        resolve_event_title("Baby Shower", "baby_shower") == canonical_event_title("baby_shower")
    )
    assert resolve_event_title("Custom", None) == "Custom"
    assert resolve_event_title("Due Date", "due_date") == "Due Date"
