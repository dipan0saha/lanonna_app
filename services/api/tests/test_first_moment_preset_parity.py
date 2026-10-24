"""First-moment preset ids in the app match the API presets.

The app shows the presets and sends their ids; the API owns titles, dates and
catalog ids. A renamed or missing id would silently seed nothing.
"""

import re
from pathlib import Path

from lanonna_api import first_moment_presets as presets

DART_PRESETS = (
    Path(__file__).resolve().parents[3]
    / "apps/mobile/lib/core/constants/first_moment_presets.dart"
)


def _dart_lists() -> dict[str, list[str]]:
    text = DART_PRESETS.read_text(encoding="utf-8")
    lists: dict[str, list[str]] = {}
    for name, body in re.findall(
        r"List<FirstMomentPreset> (\w+) = \[(.*?)\];", text, re.DOTALL
    ):
        lists[name] = re.findall(r"FirstMomentPreset\('([a-z_]+)'\)", body)
    return lists


def test_app_first_moment_preset_ids_match_api():
    dart = _dart_lists()
    assert dart == {
        "expectingEvents": [p.id for p in presets.EXPECTING_EVENTS],
        "expectingRegistry": [p.id for p in presets.EXPECTING_REGISTRY],
        "bornEvents": [p.id for p in presets.BORN_EVENTS],
        "bornRegistry": [p.id for p in presets.BORN_REGISTRY],
    }


_ASSETS = Path(__file__).resolve().parents[3] / "apps/mobile/assets"


def _catalog(path: str, title_key: str) -> dict[str, str]:
    import json

    data = json.loads((_ASSETS / path).read_text(encoding="utf-8"))
    return {row["id"]: row[title_key] for rows in data.values() for row in rows}


def test_catalog_backed_presets_match_catalog_rows():
    """A seeded preset that stands for a catalog row uses its id and name (#412),
    so the AI suggestion list stops offering what onboarding already added."""
    registry = _catalog("registry/registry_suggestions.json", "name")
    for preset in presets.EXPECTING_REGISTRY + presets.BORN_REGISTRY:
        if preset.catalog_suggestion_id is None:
            assert preset.id not in registry, preset.id
            continue
        assert preset.catalog_suggestion_id == preset.id
        assert registry[preset.id] == preset.label

    events = _catalog("calendar/event_suggestions.json", "title")
    for preset in presets.EXPECTING_EVENTS + presets.BORN_EVENTS:
        if preset.id in events:
            assert events[preset.id] == preset.label
