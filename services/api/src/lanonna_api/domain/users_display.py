"""Member display names as the API returns them.

A family-visible name is ``app_users.display_name`` only, never derived from an
email (#7). When a person has no name the API returns ``null`` and the app
shows its localized fallback (``personDisplayName`` → "Family member"); the
server never substitutes English text.
"""

from __future__ import annotations

from typing import Any


def _trimmed(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def member_display_name_from_row(row: dict[str, Any], field: str) -> str | None:
    """A member-visible name from a SQL row, or ``None`` when they have none."""
    return _trimmed(row.get(field))


def author_display_name_from_row(row: dict[str, Any]) -> str | None:
    return member_display_name_from_row(row, "author_display_name")


def uploader_display_name_from_row(row: dict[str, Any]) -> str | None:
    return member_display_name_from_row(row, "uploader_display_name")


def purchaser_display_name_from_row(row: dict[str, Any]) -> str | None:
    return member_display_name_from_row(row, "purchaser_display_name")


def rsvp_display_name_from_row(row: dict[str, Any]) -> str | None:
    return member_display_name_from_row(row, "display_name")
