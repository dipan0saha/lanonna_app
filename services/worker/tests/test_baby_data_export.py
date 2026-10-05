import uuid
from unittest.mock import MagicMock, patch

from lanonna_worker.baby_data_export import run_baby_data_export


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_run_baby_data_export_marks_ready(mock_conn_ctx, mock_storage_cls):
    job_id = uuid.uuid4()
    baby_id = uuid.uuid4()
    conn = MagicMock()

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        result = MagicMock()
        if "FROM baby_data_export_jobs" in sql_text and "WHERE id" in sql_text:
            result.fetchone.return_value = {
                "id": job_id,
                "baby_profile_id": baby_id,
                "status": "pending",
            }
        elif "UPDATE baby_data_export_jobs" in sql_text and "running" in sql_text:
            result.fetchone.return_value = {"baby_profile_id": baby_id}
        elif "FROM baby_profiles" in sql_text:
            result.fetchone.return_value = {"id": baby_id, "name": "Baby"}
        elif "FROM photos" in sql_text:
            result.fetchall.return_value = []
        elif "FROM events" in sql_text:
            result.fetchall.return_value = []
        elif "FROM registry_items" in sql_text:
            result.fetchall.return_value = []
        elif "FROM name_suggestions" in sql_text:
            result.fetchall.return_value = []
        elif "FROM activity_events" in sql_text:
            result.fetchall.return_value = []
        elif "SET status = 'ready'" in sql_text:
            result.fetchone.return_value = None
        else:
            result.fetchone.return_value = None
            result.fetchall.return_value = []
        return result

    conn.execute.side_effect = execute
    mock_conn_ctx.return_value.__enter__.return_value = conn

    blob = MagicMock()
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    run_baby_data_export(job_id)

    blob.upload_from_string.assert_called_once()
