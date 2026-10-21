"""POST /pubsub/push dispatch for storage_cleanup."""

import base64
import json
import uuid
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from lanonna_worker.main import app


def _push_body(job_id: uuid.UUID, delivery_attempt: int | None = None) -> dict:
    data = base64.b64encode(
        json.dumps({"type": "storage_cleanup", "job_id": str(job_id)}).encode()
    ).decode()
    body: dict = {"message": {"data": data, "messageId": "msg-1"}, "subscription": "sub"}
    if delivery_attempt is not None:
        body["deliveryAttempt"] = delivery_attempt
    return body


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_storage_cleanup_dispatch_returns_500_on_handler_error(client):
    job_id = uuid.uuid4()
    with patch(
        "lanonna_worker.main.run_storage_cleanup",
        side_effect=RuntimeError("gcs down"),
    ):
        resp = client.post("/pubsub/push", json=_push_body(job_id, 1))

    assert resp.status_code == 500


def test_storage_cleanup_redelivery_calls_handler_again(client):
    job_id = uuid.uuid4()
    with patch(
        "lanonna_worker.main.run_storage_cleanup",
        side_effect=[RuntimeError("boom"), None],
    ) as run:
        first = client.post("/pubsub/push", json=_push_body(job_id, 1))
        second = client.post("/pubsub/push", json=_push_body(job_id, 2))

    assert first.status_code == 500
    assert second.status_code == 204
    assert run.call_count == 2


def test_sweep_dispatch_runs_sweep(client):
    data = base64.b64encode(b'{"type":"sweep_storage_cleanup_jobs"}').decode()
    with patch("lanonna_worker.main.sweep_storage_cleanup_jobs") as sweep:
        resp = client.post(
            "/pubsub/push", json={"message": {"data": data, "messageId": "m"}}
        )

    assert resp.status_code == 204
    sweep.assert_called_once_with()
