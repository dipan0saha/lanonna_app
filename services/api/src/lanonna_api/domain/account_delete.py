from __future__ import annotations

from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth

from lanonna_api.domain.storage_cleanup import enqueue_storage_cleanup
from lanonna_api.repositories.account_delete import (
    account_is_tombstoned,
    list_sole_owned_baby_ids,
    list_sole_owned_baby_names,
    soft_delete_account_rows,
)
from lanonna_api.repositories.storage_cleanup_jobs import account_cleanup_job_needs_publish


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
    """Soft-delete SQL first, then Firebase. Retry-safe if SQL already tombstoned.

    The storage cleanup job is committed with the tombstone; it is published after
    commit. A retry after tombstone re-publishes the job if it has not completed.
    """
    if account_is_tombstoned(firebase_uid):
        job_id = account_cleanup_job_needs_publish(firebase_uid)
    else:
        sole_owned = list_sole_owned_baby_ids(firebase_uid)
        job_id = soft_delete_account_rows(firebase_uid, sole_owned)
    if job_id is not None:
        enqueue_storage_cleanup(job_id)
    _delete_firebase_user(firebase_uid)
