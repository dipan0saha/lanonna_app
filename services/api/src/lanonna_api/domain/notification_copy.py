from __future__ import annotations

from lanonna_api.repositories.users import get_app_user


def actor_display_name(firebase_uid: str) -> str:
    row = get_app_user(firebase_uid)
    if row is None:
        return "Someone"
    if row.get("display_name"):
        return str(row["display_name"]).strip() or "Someone"
    email = row.get("email") or ""
    if email and "@" in email:
        return email.split("@")[0]
    return "Someone"
