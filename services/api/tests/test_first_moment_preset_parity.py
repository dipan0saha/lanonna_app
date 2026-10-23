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
