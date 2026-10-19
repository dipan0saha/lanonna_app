from __future__ import annotations

from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth

from lanonna_api.repositories.account_delete import (
    account_is_tombstoned,
    list_sole_owned_baby_ids,
    list_sole_owned_baby_names,
    soft_delete_account_rows,
)


def delete_account_preview(firebase_uid: str) -> dict[str, Any]:
    """What deleting this account will remove, for the confirm dialog.

    Deletion is never blocked (FR-SET-005): sole-owned baby profiles are deleted
    with the account and co-owned ones pass to the remaining owner, so the only
    thing to preview is ``sole_owned_babies``.
    """
    return {"sole_owned_babies": list_sole_owned_baby_names(firebase_uid)}


def _delete_firebase_user(firebase_uid: str) -> None:
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    try:
        firebase_auth.delete_user(firebase_uid)
    except firebase_auth.UserNotFoundError:
        pass
    except Exception as exc:
        raise RuntimeError("Could not delete Firebase user") from exc


def delete_account(firebase_uid: str) -> None:
    """Soft-delete SQL first, then Firebase. Retry-safe if SQL already tombstoned."""
    already_deleted = account_is_tombstoned(firebase_uid)
    if not already_deleted:
        sole_owned = list_sole_owned_baby_ids(firebase_uid)
        soft_delete_account_rows(firebase_uid, sole_owned)
    _delete_firebase_user(firebase_uid)
