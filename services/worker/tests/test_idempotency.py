from unittest.mock import MagicMock, patch

import uuid

from lanonna_worker.idempotency import (
    resolve_delivery_key,
    try_claim_delivery,
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
            "kind": "event_rsvp",
            "params": {},
        },
        pubsub_message_id="dup-msg",
    )

    assert conn.execute.call_count == 1


@patch("lanonna_worker.notifications._deliver_to_inbox_and_push")
@patch("lanonna_worker.notifications._load_recipients", return_value=["recipient"])
@patch("lanonna_worker.notifications._resolve_recipient_uids", return_value=["u1"])
@patch("lanonna_worker.notifications.get_connection")
def test_notify_fan_out_claims_delivery_key(
    mock_conn_ctx,
    _resolve,
    mock_load,
    mock_deliver,
):
    conn = MagicMock()
    mock_conn_ctx.return_value.__enter__.return_value = conn
    conn.execute.return_value.fetchone.return_value = {"delivery_key": "k"}

    baby_id = uuid.uuid4()
    process_notify_fan_out(
        {
            "baby_profile_id": str(baby_id),
            "kind": "photo_shared",
            "params": {},
            "deep_link": "/home",
        },
        pubsub_message_id="msg-fan-out",
    )

    mock_load.assert_called_once_with(conn, ["u1"], None)
    mock_deliver.assert_called_once()
    assert mock_deliver.call_args.args[1] == ["recipient"]
    first_sql = conn.execute.call_args_list[0][0][0]
    assert "worker_delivery_log" in first_sql
