from __future__ import annotations

import re
from datetime import date
from typing import Any

from lanonna_api.domain.home import validate_actual_birth_date

_ALLOWED_GENDERS = frozenset({"male", "female", "unknown"})
_BIRTH_TIME_RE = re.compile(r"^([01]?\d|2[0-3]):[0-5]\d$")


def validate_announcement_gender(gender: str | None) -> None:
    if gender is None:
        return
    if gender not in _ALLOWED_GENDERS:
        raise ValueError("Gender must be male, female, or unknown.")


def validate_announcement_birth_date(birth_date: date | None) -> None:
    if birth_date is None:
        return
    validate_actual_birth_date(birth_date)


def validate_announcement_birth_time(birth_time: str | None) -> None:
    if birth_time is None:
        return
    trimmed = birth_time.strip()
    if not trimmed:
        return
    if not _BIRTH_TIME_RE.match(trimmed):
        raise ValueError("Birth time must use 24-hour HH:MM format.")


def validate_announcement_fields(
    *,
    gender: str | None = None,
    birth_date: date | None = None,
    birth_time: str | None = None,
) -> None:
    validate_announcement_gender(gender)
    validate_announcement_birth_date(birth_date)
    validate_announcement_birth_time(birth_time)


def merge_announcement_patch(existing: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    keys = (
        "first_name",
        "last_name",
        "gender",
        "birth_date",
        "birth_time",
        "weight_text",
        "length_text",
        "photo_id",
    )
    merged = {key: existing.get(key) for key in keys}
    for key, value in patch.items():
        if key in keys:
            merged[key] = value
    return merged
