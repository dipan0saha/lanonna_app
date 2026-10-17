"""Permanent poison Pub/Sub payloads are acked (204), not retried."""

import base64
import json
import uuid
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from lanonna_worker.invite_email import InviteSendOutcome
from lanonna_worker.main import app


def _push(data: dict, delivery_attempt: int | None = None) -> dict:
    encoded = base64.b64encode(json.dumps(data).encode()).decode()
    body: dict = {"message": {"data": encoded, "messageId": "msg-1"}, "subscription": "sub"}
    if delivery_attempt is not None:
        body["deliveryAttempt"] = delivery_attempt
    return body


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_invalid_base64_is_acked(client):
    with patch("lanonna_worker.main.run_baby_data_export") as run:
        resp = client.post(
            "/pubsub/push",
            json={"message": {"data": "!!!not-base64!!!", "messageId": "m1"}},
        )
    assert resp.status_code == 204
    run.assert_not_called()


def test_baby_data_export_invalid_job_id_is_acked(client):
    with patch("lanonna_worker.main.run_baby_data_export") as run:
        resp = client.post(
            "/pubsub/push",
            json=_push({"type": "baby_data_export", "job_id": "not-a-uuid"}),
        )
    assert resp.status_code == 204
    run.assert_not_called()


def test_notify_fan_out_invalid_baby_uuid_is_acked(client):
    with patch("lanonna_worker.main.process_notify_fan_out") as proc:
        resp = client.post(
            "/pubsub/push",
            json=_push(
                {
                    "type": "notify_fan_out",
                    "baby_profile_id": "bad",
                    "kind": "photo_shared",
                }
            ),
        )
    assert resp.status_code == 204
    proc.assert_not_called()


def test_notify_user_legacy_title_body_payload_is_acked(client):
    with patch("lanonna_worker.main.process_notify_user") as proc:
        resp = client.post(
            "/pubsub/push",
            json=_push({"type": "notify_user", "firebase_uid": "u1", "title": "t", "body": "b"}),
        )
    assert resp.status_code == 204
    proc.assert_not_called()


def test_baby_data_export_transient_failure_still_500(client):
    job_id = uuid.uuid4()
    with patch(
        "lanonna_worker.main.run_baby_data_export",
        side_effect=RuntimeError("boom"),
    ):
        resp = client.post("/pubsub/push", json=_push({"type": "baby_data_export", "job_id": str(job_id)}, 1))
    assert resp.status_code == 500


def test_send_invite_invalid_invitation_id_is_acked(client):
    with patch("lanonna_worker.main.send_invite_email") as send:
        resp = client.post(
            "/pubsub/push",
            json=_push({"type": "send_invite_email", "invitation_id": "nope"}),
        )
    assert resp.status_code == 204
    send.assert_not_called()


def test_send_invite_transient_failure_returns_500(client):
    inv_id = uuid.uuid4()
    with patch(
        "lanonna_worker.main.send_invite_email",
        return_value=InviteSendOutcome.RETRY,
    ) as send:
        resp = client.post(
            "/pubsub/push",
            json=_push(
                {"type": "send_invite_email", "invitation_id": str(inv_id)},
                delivery_attempt=2,
            ),
        )
    assert resp.status_code == 500
    send.assert_called_once()
    assert send.call_args.kwargs["final_attempt"] is False


def test_send_invite_permanent_failure_is_acked(client):
    inv_id = uuid.uuid4()
    with patch(
        "lanonna_worker.main.send_invite_email",
        return_value=InviteSendOutcome.FAILED,
    ):
        resp = client.post(
            "/pubsub/push",
            json=_push(
                {"type": "send_invite_email", "invitation_id": str(inv_id)},
                delivery_attempt=12,
            ),
        )
    assert resp.status_code == 204
