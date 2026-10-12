import uuid
from unittest.mock import MagicMock, patch

import pytest

from lanonna_worker.baby_data_export import run_baby_data_export


@pytest.fixture(autouse=True)
def _stub_export_body(monkeypatch):
    monkeypatch.setattr(
        "lanonna_worker.baby_data_export.build_baby_export_json",
        lambda *args, **kwargs: b'{"export_version": 2}\n',
    )


def _make_conn(job_status: str, baby_id: uuid.UUID):
    """Mock connection that records executed SQL; the claim honours the job status."""
    conn = MagicMock()
    calls: list[tuple[str, tuple]] = []

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        calls.append((sql_text, tuple(params or ())))
        result = MagicMock()
        if sql_text.startswith("SELECT id, baby_profile_id, status FROM baby_data_export_jobs"):
            result.fetchone.return_value = {
                "id": params[0],
                "baby_profile_id": baby_id,
                "status": job_status,
            }
        elif "SET status = 'running'" in sql_text and "started_at = now()" in sql_text:
            redelivery = params[1]
            claimable = job_status == "pending" or (job_status == "running" and redelivery)
            result.fetchone.return_value = (
                {
                    "baby_profile_id": baby_id,
                    "requested_by_firebase_uid": "owner-1",
                }
                if claimable
                else None
            )
        elif "SET started_at = now()" in sql_text and "status = 'running'" in sql_text:
            result.fetchone.return_value = None
        elif "FROM baby_profiles" in sql_text:
            result.fetchone.return_value = {"id": baby_id, "name": "Baby"}
        elif "COUNT(*)::int AS n" in sql_text and "activity_events" in sql_text:
            result.fetchone.return_value = {"n": 0}
        else:
            result.fetchone.return_value = None
            result.fetchall.return_value = []
        return result

    conn.execute.side_effect = execute
    return conn, calls


def _statuses_set(calls: list[tuple[str, tuple]]) -> set[str]:
    """Final statuses written by UPDATEs on the job row (excluding the claim and reclaim)."""
    found: set[str] = set()
    for sql_text, _ in calls:
        if not sql_text.startswith("UPDATE baby_data_export_jobs"):
            continue
        if "interval '30 minutes'" in sql_text or "SET status = 'running'" in sql_text:
            continue
        for status in ("ready", "failed", "pending"):
            if f"SET status = '{status}'" in sql_text:
                found.add(status)
    return found


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_run_baby_data_export_marks_ready(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("pending", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    run_baby_data_export(job_id)

    blob.upload_from_string.assert_called_once()
    assert _statuses_set(calls) == {"ready"}


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_final_attempt_failure_marks_job_failed(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("pending", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    blob.upload_from_string.side_effect = RuntimeError("gcs down")
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    with pytest.raises(RuntimeError, match="gcs down"):
        run_baby_data_export(job_id, final_attempt=True)

    assert _statuses_set(calls) == {"failed"}


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_non_final_failure_releases_claim_for_retry(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("pending", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    blob.upload_from_string.side_effect = RuntimeError("gcs down")
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    with pytest.raises(RuntimeError, match="gcs down"):
        run_baby_data_export(job_id, final_attempt=False)

    assert _statuses_set(calls) == {"pending"}


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_redelivery_takes_over_a_running_job(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("running", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    run_baby_data_export(job_id, redelivery=True, final_attempt=False)

    blob.upload_from_string.assert_called_once()
    assert _statuses_set(calls) == {"ready"}


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_happy_path_touches_export_heartbeat(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("pending", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    run_baby_data_export(job_id)

    heartbeat_sql = [
        sql for sql, _ in calls if "SET started_at = now()" in sql and "status = 'running'" in sql
    ]
    assert len(heartbeat_sql) >= 2


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_ready_update_zero_rows_deletes_uploaded_blob(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("pending", baby_id)

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        calls.append((sql_text, tuple(params or ())))
        result = MagicMock()
        if sql_text.startswith("SELECT id, baby_profile_id, status FROM baby_data_export_jobs"):
            result.fetchone.return_value = {
                "id": params[0],
                "baby_profile_id": baby_id,
                "status": "pending",
            }
        elif "SET status = 'running'" in sql_text and "started_at = now()" in sql_text:
            result.fetchone.return_value = {
                "baby_profile_id": baby_id,
                "requested_by_firebase_uid": "owner-1",
            }
        elif "SET status = 'ready'" in sql_text:
            result.rowcount = 0
        elif "FROM baby_profiles" in sql_text:
            result.fetchone.return_value = {"id": baby_id, "name": "Baby"}
        else:
            result.fetchone.return_value = None
            result.fetchall.return_value = []
        return result

    conn.execute.side_effect = execute
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    run_baby_data_export(job_id)

    blob.delete.assert_called_once()


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_upload_then_ready_failure_deletes_blob_and_marks_failed(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("pending", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn
    blob = MagicMock()
    mock_storage_cls.return_value.bucket.return_value.blob.return_value = blob

    original_execute = conn.execute.side_effect

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        if "SET status = 'ready'" in sql_text:
            raise RuntimeError("db down")
        return original_execute(sql, params)

    conn.execute.side_effect = execute

    with pytest.raises(RuntimeError, match="db down"):
        run_baby_data_export(job_id, final_attempt=True)

    blob.delete.assert_called_once()
    assert _statuses_set(calls) == {"failed"}


@patch("lanonna_worker.baby_data_export.storage.Client")
@patch("lanonna_worker.baby_data_export.get_connection")
def test_first_delivery_does_not_take_over_a_running_job(mock_conn_ctx, mock_storage_cls):
    job_id, baby_id = uuid.uuid4(), uuid.uuid4()
    conn, calls = _make_conn("running", baby_id)
    mock_conn_ctx.return_value.__enter__.return_value = conn

    run_baby_data_export(job_id, redelivery=False)

    mock_storage_cls.assert_not_called()
    assert _statuses_set(calls) == set()
