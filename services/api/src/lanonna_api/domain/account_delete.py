from __future__ import annotations

import logging
import uuid
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth

from lanonna_api.pubsub import publish_storage_cleanup
from lanonna_api.repositories.account_delete import (
    account_is_tombstoned,
    list_sole_owned_baby_ids,
    list_sole_owned_baby_names,
    soft_delete_account_rows,
)
from lanonna_api.repositories.storage_cleanup_jobs import account_cleanup_job_needs_publish

logger = logging.getLogger("lanonna.api.account_delete")


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


def _safe_publish_storage_cleanup(job_id: uuid.UUID) -> None:
    try:
        publish_storage_cleanup(job_id)
    except Exception:
        logger.exception("storage_cleanup_publish_failed job_id=%s", job_id)


def _ensure_storage_cleanup_enqueued(
    firebase_uid: str,
    job_id: uuid.UUID | None,
) -> None:
    to_publish = job_id or account_cleanup_job_needs_publish(firebase_uid)
    if to_publish is not None:
        _safe_publish_storage_cleanup(to_publish)


def delete_account(firebase_uid: str) -> None:
    """Soft-delete SQL first, then Firebase. Retry-safe if SQL already tombstoned."""
    already_deleted = account_is_tombstoned(firebase_uid)
    job_id: uuid.UUID | None = None
    if not already_deleted:
        sole_owned = list_sole_owned_baby_ids(firebase_uid)
        job_id = soft_delete_account_rows(firebase_uid, sole_owned)
    _ensure_storage_cleanup_enqueued(firebase_uid, job_id)
    _delete_firebase_user(firebase_uid)
