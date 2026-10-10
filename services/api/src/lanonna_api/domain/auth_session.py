from __future__ import annotations

from lanonna_api.repositories.users import get_app_user_including_tombstone


class UserDeletedError(Exception):
    """Raised when a Firebase UID maps to a tombstoned app_users row (NFR-DATA-001)."""


def assert_active_user(firebase_uid: str) -> None:
    row = get_app_user_including_tombstone(firebase_uid)
    if row is not None and row.get("deleted_at") is not None:
        raise UserDeletedError()
