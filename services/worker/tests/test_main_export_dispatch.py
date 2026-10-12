"""POST /pubsub/push dispatch for baby_data_export (H-09: retries must reach the handler)."""

import base64
import json
import uuid
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from lanonna_worker.main import app


def _push_body(job_id: uuid.UUID, delivery_attempt: int | None = None) -> dict:
    data = base64.b64encode(
        json.dumps({"type": "baby_data_export", "job_id": str(job_id)}).encode()
    ).decode()
    body: dict = {"message": {"data": data, "messageId": "msg-1"}, "subscription": "sub"}
    if delivery_attempt is not None:
        body["deliveryAttempt"] = delivery_attempt
    return body


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.mark.parametrize(
    ("attempt", "redelivery", "final_attempt"),
    [
        (None, False, True),  # no DLQ info: fail visibly rather than retry blindly
        (1, False, False),
        (2, True, False),
        (4, True, False),
        (11, True, False),
        (12, True, True),
    ],
)
def test_export_dispatch_maps_delivery_attempt(client, attempt, redelivery, final_attempt):
    job_id = uuid.uuid4()
    with patch("lanonna_worker.main.run_baby_data_export") as run:
        resp = client.post("/pubsub/push", json=_push_body(job_id, attempt))

    assert resp.status_code == 204
    run.assert_called_once_with(job_id, redelivery=redelivery, final_attempt=final_attempt)


def test_redelivery_of_same_message_id_is_not_dropped(client):
    """The same messageId redelivered after a 500 must run again."""
    job_id = uuid.uuid4()
    with patch(
        "lanonna_worker.main.run_baby_data_export",
        side_effect=[RuntimeError("boom"), None],
    ) as run:
        first = client.post("/pubsub/push", json=_push_body(job_id, 1))
        second = client.post("/pubsub/push", json=_push_body(job_id, 2))

    assert first.status_code == 500
    assert second.status_code == 204
    assert run.call_count == 2


def test_export_without_job_id_is_acked(client):
    data = base64.b64encode(json.dumps({"type": "baby_data_export"}).encode()).decode()
    with patch("lanonna_worker.main.run_baby_data_export") as run:
        resp = client.post("/pubsub/push", json={"message": {"data": data}})

    assert resp.status_code == 204
    run.assert_not_called()
