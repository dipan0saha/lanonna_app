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


def delete_account_eligibility(firebase_uid: str) -> dict[str, Any]:
    """Always allowed in v1. ``sole_owned_babies`` names the profiles delete will remove."""
    return {
        "allowed": True,
        "blockers": [],
        "sole_owned_babies": list_sole_owned_baby_names(firebase_uid),
    }


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
