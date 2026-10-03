from __future__ import annotations

from typing import Any


def author_display_name_from_row(row: dict[str, Any]) -> str:
    if row.get("author_display_name"):
        return row["author_display_name"]
    email = row.get("author_email") or ""
    if email and "@" in email:
        return email.split("@")[0]
    return "Family member"
