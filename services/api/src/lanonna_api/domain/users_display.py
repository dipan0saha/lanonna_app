from __future__ import annotations

from typing import Any

from lanonna_api.repositories.users import get_app_user

FAMILY_MEMBER_LABEL = "Family member"
UNKNOWN_ACTOR_LABEL = "Someone"


def _trimmed(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def member_display_name_from_row(row: dict[str, Any], field: str) -> str:
    """Resolve a member-visible label from a SQL row; never uses email."""
    return _trimmed(row.get(field)) or FAMILY_MEMBER_LABEL


def author_display_name_from_row(row: dict[str, Any]) -> str:
    return member_display_name_from_row(row, "author_display_name")


def uploader_display_name_from_row(row: dict[str, Any]) -> str:
    return member_display_name_from_row(row, "uploader_display_name")


def purchaser_display_name_from_row(row: dict[str, Any]) -> str:
    return member_display_name_from_row(row, "purchaser_display_name")


def rsvp_display_name_from_row(row: dict[str, Any]) -> str:
    return member_display_name_from_row(row, "display_name")


def actor_display_name(firebase_uid: str) -> str:
    """Actor label for activity events and notifications (not email-derived)."""
    row = get_app_user(firebase_uid)
    if row is None:
        return UNKNOWN_ACTOR_LABEL
    return _trimmed(row.get("display_name")) or UNKNOWN_ACTOR_LABEL
