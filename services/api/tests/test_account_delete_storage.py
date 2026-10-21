import uuid
from unittest.mock import MagicMock, patch

from lanonna_api.domain.account_delete import delete_account
from lanonna_api.repositories.account_delete_media import (
    purge_authored_photos_on_shared_babies,
)


def test_purge_authored_photos_on_shared_babies_is_one_delete_returning_paths():
    conn = MagicMock()
    sole_owned = [uuid.uuid4()]
    conn.execute.return_value.fetchall.return_value = [
        {"display_path": "display/x.webp", "thumb_path": "thumbnails/x.jpg"}
    ]

    detached = purge_authored_photos_on_shared_babies(conn, "uploader-1", sole_owned)

    assert detached == [
        {"display_path": "display/x.webp", "thumb_path": "thumbnails/x.jpg"}
    ]
    conn.execute.assert_called_once()
    sql, params = conn.execute.call_args.args
    assert "DELETE FROM photos" in sql and "RETURNING" in sql
    assert params == ("uploader-1", sole_owned)


def test_delete_account_publishes_storage_cleanup_after_sql():
    job_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.delete_account_rows",
            return_value=job_id,
        ) as soft_delete,
        patch(
            "lanonna_api.domain.storage_cleanup.publish_storage_cleanup",
        ) as publish,
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch("lanonna_api.domain.account_delete.firebase_auth.delete_user"),
    ):
        delete_account("uid-1")

    soft_delete.assert_called_once()
    publish.assert_called_once_with(job_id)


def test_delete_account_retry_republishes_incomplete_cleanup_job():
    job_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.account_delete.account_cleanup_job_needs_publish",
            return_value=job_id,
        ),
        patch(
            "lanonna_api.domain.account_delete.delete_account_rows",
        ) as soft_delete,
        patch(
            "lanonna_api.domain.storage_cleanup.publish_storage_cleanup",
        ) as publish,
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch("lanonna_api.domain.account_delete.firebase_auth.delete_user"),
    ):
        delete_account("uid-retry")

    soft_delete.assert_not_called()
    publish.assert_called_once_with(job_id)


def test_delete_account_swallows_pubsub_publish_errors():
    job_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.delete_account_rows",
            return_value=job_id,
        ),
        patch(
            "lanonna_api.domain.storage_cleanup.publish_storage_cleanup",
            side_effect=RuntimeError("pubsub down"),
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
        ) as delete_user,
    ):
        delete_account("uid-1")

    delete_user.assert_called_once()


def test_delete_account_retry_with_completed_job_does_not_publish():
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.account_delete.account_cleanup_job_needs_publish",
            return_value=None,
        ),
        patch(
            "lanonna_api.domain.storage_cleanup.publish_storage_cleanup",
        ) as publish,
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch("lanonna_api.domain.account_delete.firebase_auth.delete_user"),
    ):
        delete_account("uid-done")

    publish.assert_not_called()
