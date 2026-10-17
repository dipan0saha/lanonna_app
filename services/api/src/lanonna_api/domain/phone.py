"""Optional profile phone numbers.

Empty input clears the field. A value must be digits with optional spaces,
``+``, ``-``, and parentheses, and contain 7–20 digits. A leading ``+`` is
kept so the stored value is E.164-ish (``+`` plus digits, or digits only).
"""

from __future__ import annotations

import re
from lanonna_api.domain.errors import ErrorCode, InvalidInputError

_ALLOWED = re.compile(r"^[0-9+\-() ]+$")
_NON_DIGITS = re.compile(r"\D")


def normalize_optional_phone(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    if not _ALLOWED.fullmatch(trimmed):
        raise InvalidInputError(ErrorCode.INVALID_PHONE, "Enter a valid phone number")
    if "+" in trimmed and not trimmed.startswith("+"):
        raise InvalidInputError(ErrorCode.INVALID_PHONE, "Enter a valid phone number")
    if trimmed.count("+") > 1:
        raise InvalidInputError(ErrorCode.INVALID_PHONE, "Enter a valid phone number")
    digits = _NON_DIGITS.sub("", trimmed)
    if not 7 <= len(digits) <= 20:
        raise InvalidInputError(ErrorCode.INVALID_PHONE, "Enter a valid phone number")
    if trimmed.startswith("+"):
        return f"+{digits}"
    return digits
