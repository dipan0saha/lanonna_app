from __future__ import annotations

import uuid
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth

from lanonna_api.repositories.account_delete import (
    list_sole_owned_baby_ids,
    soft_delete_account_rows,
)


def delete_account_eligibility(firebase_uid: str) -> dict[str, Any]:
    sole = list_sole_owned_baby_ids(firebase_uid)
    blockers = [f"sole_owner_of_baby:{baby_id}" for baby_id in sole]
    return {"allowed": len(blockers) == 0, "blockers": blockers}


def delete_account(firebase_uid: str) -> None:
    eligibility = delete_account_eligibility(firebase_uid)
    if not eligibility["allowed"]:
        raise PermissionError(
            "Transfer or remove owned baby profiles before deleting your account."
        )

    soft_delete_account_rows(firebase_uid)

    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    firebase_auth.delete_user(firebase_uid)
