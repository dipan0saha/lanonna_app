import uuid
from unittest.mock import MagicMock, patch

import pytest

from lanonna_worker.gcs_delete import GcsDeleteError
from lanonna_worker.storage_cleanup import run_storage_cleanup


def _make_conn(job_status: str):
    conn = MagicMock()
    job_id = uuid.uuid4()
    baby_id = uuid.uuid4()

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        result = MagicMock()
        if sql_text.startswith("SELECT id, status, firebase_uid"):
            result.fetchone.return_value = {
                "id": job_id,
                "status": job_status,
                "firebase_uid": "user-1",
                "baby_profile_ids": [baby_id],
                "detached_objects": [
                    {"display_path": "display/detached.webp", "thumb_path": "thumbnails/d.jpg"}
                ],
                "export_object_paths": ["exports/b/j/export.json"],
            }
        elif "SET status = 'running'" in sql_text and "RETURNING" in sql_text:
            redelivery = params[1]
            claimable = job_status == "pending" or (job_status == "running" and redelivery)
            result.fetchone.return_value = (
                {
                    "firebase_uid": "user-1",
                    "baby_profile_ids": [baby_id],
                    "detached_objects": [
                        {
                            "display_path": "display/detached.webp",
                            "thumb_path": "thumbnails/d.jpg",
                        }
                    ],
                    "export_object_paths": ["exports/b/j/export.json"],
                }
                if claimable
                else None
            )
        elif "FROM photos" in sql_text:
            result.fetchall.return_value = [
                {"display_path": "display/baby.webp", "thumb_path": "thumbnails/b.jpg"}
            ]
        else:
            result.fetchone.return_value = None
            result.fetchall.return_value = []
        return result

    conn.execute.side_effect = execute
    return conn, job_id, baby_id


@patch("lanonna_worker.storage_cleanup.gcs_delete.delete_prefix")
@patch("lanonna_worker.storage_cleanup.gcs_delete.delete_display_paths")
@patch("lanonna_worker.storage_cleanup.gcs_delete.delete_photo_paths")
@patch("lanonna_worker.storage_cleanup.get_connection")
def test_run_storage_cleanup_completes_job(
    mock_conn_ctx, mock_photo_paths, mock_display_paths, mock_prefix
):
    conn, job_id, _baby = _make_conn("pending")
    mock_conn_ctx.return_value.__enter__.return_value = conn
    mock_photo_paths.return_value = 2
    mock_display_paths.return_value = 1
    mock_prefix.return_value = 3

    run_storage_cleanup(job_id)

    assert mock_photo_paths.call_count >= 2
    mock_display_paths.assert_called_once()
    assert mock_prefix.call_count >= 2


@patch("lanonna_worker.storage_cleanup.gcs_delete.delete_photo_paths")
@patch("lanonna_worker.storage_cleanup.get_connection")
def test_run_storage_cleanup_idempotent_when_completed(mock_conn_ctx, mock_photo_paths):
    conn = MagicMock()
    job_id = uuid.uuid4()

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        result = MagicMock()
        if sql_text.startswith("SELECT id, status"):
            result.fetchone.return_value = {
                "id": job_id,
                "status": "completed",
                "firebase_uid": "user-1",
                "baby_profile_ids": [],
                "detached_objects": [],
                "export_object_paths": [],
            }
        return result

    conn.execute.side_effect = execute
    mock_conn_ctx.return_value.__enter__.return_value = conn

    run_storage_cleanup(job_id)

    mock_photo_paths.assert_not_called()


@patch("lanonna_worker.storage_cleanup.gcs_delete.delete_photo_paths")
@patch("lanonna_worker.storage_cleanup.get_connection")
def test_run_storage_cleanup_retries_on_gcs_failure(mock_conn_ctx, mock_photo_paths):
    conn, job_id, _ = _make_conn("pending")
    mock_conn_ctx.return_value.__enter__.return_value = conn
    mock_photo_paths.side_effect = GcsDeleteError("boom")

    with pytest.raises(GcsDeleteError):
        run_storage_cleanup(job_id, final_attempt=False)

    release_sql = [
        " ".join(call.args[0].split())
        for call in conn.execute.call_args_list
        if call.args and "SET status = 'pending'" in call.args[0]
    ]
    assert release_sql
