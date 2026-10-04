from unittest.mock import MagicMock, patch

import uuid

from lanonna_worker.idempotency import (
    resolve_delivery_key,
    try_claim_delivery,
    try_claim_photo_ready_notify,
)
from lanonna_worker.notifications import process_notify_fan_out, process_notify_user


def test_resolve_delivery_key_prefers_explicit():
    key = resolve_delivery_key(
        {"dedupe_key": "custom"},
        pubsub_message_id="msg-1",
    )
    assert key == "custom"


def test_resolve_delivery_key_uses_pubsub_id():
    key = resolve_delivery_key({}, pubsub_message_id="msg-2")
    assert key == "pubsub:msg-2"


def test_try_claim_delivery_first_time():
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = {"delivery_key": "k1"}
    assert try_claim_delivery(conn, "k1") is True


def test_try_claim_delivery_duplicate():
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = None
    assert try_claim_delivery(conn, "k1") is False


def test_try_claim_photo_ready_notify():
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = {"photo_id": uuid.uuid4()}
    photo_id = uuid.uuid4()
    assert try_claim_photo_ready_notify(conn, photo_id, 42) is True


@patch("lanonna_worker.notifications.get_connection")
def test_notify_user_skips_duplicate_delivery(mock_conn_ctx):
    conn = MagicMock()
    mock_conn_ctx.return_value.__enter__.return_value = conn
    conn.execute.return_value.fetchone.side_effect = [
        None,  # try_claim_delivery duplicate
    ]

    process_notify_user(
        {
            "firebase_uid": "u1",
            "title": "T",
            "body": "B",
        },
        pubsub_message_id="dup-msg",
    )

    assert conn.execute.call_count == 1


@patch("lanonna_worker.notifications._send_fcm")
@patch("lanonna_worker.notifications._insert_notification")
@patch("lanonna_worker.notifications._user_channel_enabled", return_value=True)
@patch("lanonna_worker.notifications._resolve_recipient_uids", return_value=["u1"])
@patch("lanonna_worker.notifications.get_connection")
def test_notify_fan_out_claims_delivery_key(
    mock_conn_ctx,
    _resolve,
    _channel,
    mock_insert,
    _fcm,
):
    conn = MagicMock()
    mock_conn_ctx.return_value.__enter__.return_value = conn
    conn.execute.return_value.fetchone.return_value = {"delivery_key": "k"}

    baby_id = uuid.uuid4()
    process_notify_fan_out(
        {
            "baby_profile_id": str(baby_id),
            "title": "T",
            "body": "B",
            "deep_link": "/home",
        },
        pubsub_message_id="msg-fan-out",
    )

    mock_insert.assert_called_once()
    first_sql = conn.execute.call_args_list[0][0][0]
    assert "worker_delivery_log" in first_sql
