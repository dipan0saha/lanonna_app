import uuid
from unittest.mock import MagicMock, patch

from lanonna_api.domain.account_delete import delete_account
from lanonna_api.repositories.account_delete_media import (
    purge_authored_photos_on_shared_babies,
)


def test_purge_authored_photos_on_shared_babies_returns_paths_and_deletes_rows():
    conn = MagicMock()
    baby_shared = uuid.uuid4()
    sole_owned = [uuid.uuid4()]
    photo_id = uuid.uuid4()
    conn.execute.return_value.fetchall.side_effect = [
        [
            {
                "id": photo_id,
                "display_path": "display/x.webp",
                "thumb_path": "thumbnails/x.jpg",
            }
        ],
        None,
        None,
        None,
        None,
        None,
    ]

    detached = purge_authored_photos_on_shared_babies(
        conn, "uploader-1", sole_owned
    )

    assert detached == [
        {"display_path": "display/x.webp", "thumb_path": "thumbnails/x.jpg"}
    ]
    delete_calls = [
        call.args[0]
        for call in conn.execute.call_args_list
        if "DELETE FROM photos" in call.args[0]
    ]
    assert delete_calls


def test_delete_account_publishes_storage_cleanup_after_sql():
    job_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.account_delete.account_is_tombstoned",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[],
        ),
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
            return_value=job_id,
        ) as soft_delete,
        patch(
            "lanonna_api.domain.account_delete.publish_storage_cleanup",
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
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
        ) as soft_delete,
        patch(
            "lanonna_api.domain.account_delete.publish_storage_cleanup",
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
            "lanonna_api.domain.account_delete.list_sole_owned_baby_ids",
            return_value=[],
        ),
        patch(
            "lanonna_api.domain.account_delete.soft_delete_account_rows",
            return_value=job_id,
        ),
        patch(
            "lanonna_api.domain.account_delete.publish_storage_cleanup",
            side_effect=RuntimeError("pubsub down"),
        ),
        patch("lanonna_api.domain.account_delete.firebase_admin._apps", [object()]),
        patch(
            "lanonna_api.domain.account_delete.firebase_auth.delete_user",
        ) as delete_user,
    ):
        delete_account("uid-1")

    delete_user.assert_called_once()
