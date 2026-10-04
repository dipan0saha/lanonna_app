from __future__ import annotations

from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth

from lanonna_api.repositories.account_delete import (
    list_sole_owned_baby_ids,
    soft_delete_account_rows,
)


def delete_account_eligibility(firebase_uid: str) -> dict[str, Any]:
    return {"allowed": True, "blockers": []}


def delete_account(firebase_uid: str) -> None:
    sole_owned = list_sole_owned_baby_ids(firebase_uid)

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    try:
        firebase_auth.delete_user(firebase_uid)
    except firebase_auth.UserNotFoundError:
        pass
    except Exception as exc:
        raise RuntimeError("Could not delete Firebase user") from exc

    soft_delete_account_rows(firebase_uid, sole_owned)
