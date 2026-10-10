from __future__ import annotations

from lanonna_api.domain.user_errors import UserDeletedError
from lanonna_api.repositories.users import get_app_user_including_tombstone

__all__ = ["UserDeletedError", "assert_active_user"]


def assert_active_user(firebase_uid: str) -> None:
    row = get_app_user_including_tombstone(firebase_uid)
    if row is not None and row.get("deleted_at") is not None:
        raise UserDeletedError()
