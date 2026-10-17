"""API ErrorCode values and the app's ApiErrorCode enum stay in sync.

The app localizes errors by code; a code the app does not know falls back to
generic copy, so every server code must exist in the Dart enum (and the app
must not expect codes the server never sends, other than its client-only ones).
"""

import re
from pathlib import Path

from lanonna_api.domain.errors import ErrorCode

DART_ENUM = (
    Path(__file__).resolve().parents[3]
    / "apps/mobile/lib/core/api/api_error_code.dart"
)
CLIENT_ONLY = {"network_unavailable", "network_timeout"}


def _dart_codes() -> set[str]:
    text = DART_ENUM.read_text(encoding="utf-8")
    body = text[text.index("enum ApiErrorCode {") : text.index("const ApiErrorCode(")]
    return set(re.findall(r"^\s+\w+\('([a-z_]+)'\)[,;]", body, re.MULTILINE))


def test_app_error_codes_match_api_error_codes():
    dart = _dart_codes()
    assert CLIENT_ONLY <= dart
    assert dart - CLIENT_ONLY == {code.value for code in ErrorCode}
