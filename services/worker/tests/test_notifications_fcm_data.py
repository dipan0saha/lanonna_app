import uuid
from unittest.mock import MagicMock, patch

from lanonna_worker.notifications import _Recipient, _deliver_to_inbox_and_push


def _recipient(uid: str, *, channel=True, realtime=True, tokens=("tok",)) -> _Recipient:
    return _Recipient(
        firebase_uid=uid,
        channel_enabled=channel,
        realtime_push=realtime,
        fcm_tokens=tuple(tokens),
    )


@patch("lanonna_worker.notifications.messaging.send_each_for_multicast")
@patch("lanonna_worker.notifications._ensure_fcm")
def test_push_data_carries_inbox_row_and_baby_profile_id(_ensure, mock_send):
    mock_send.return_value = MagicMock(responses=[MagicMock(success=True)])
    conn = MagicMock()
    baby_id = uuid.uuid4()

    _deliver_to_inbox_and_push(
        conn,
        [_recipient("u1", tokens=("tok1",))],
        title="T",
        body="B",
        deep_link="/gallery/photo/x",
        baby_profile_id=baby_id,
        notification_type="photo",
        actor_firebase_uid=None,
    )

    insert_params = conn.execute.call_args_list[0].args[1]
    inserted_ids, inserted_uids = insert_params[5], insert_params[6]
    assert inserted_uids == ["u1"]
    message = mock_send.call_args[0][0]
    assert message.tokens == ["tok1"]
    assert message.data["deep_link"] == "/gallery/photo/x"
    assert message.data["notification_id"] == str(inserted_ids[0])
    assert message.data["baby_profile_id"] == str(baby_id)


@patch("lanonna_worker.notifications._send_push")
def test_one_insert_for_all_recipients_and_push_only_where_allowed(mock_push):
    conn = MagicMock()

    _deliver_to_inbox_and_push(
        conn,
        [
            _recipient("on"),
            _recipient("muted_channel", channel=False),
            _recipient("digest_user", realtime=False),
            _recipient("no_device", tokens=()),
        ],
        title="T",
        body="B",
        deep_link=None,
        baby_profile_id=None,
        notification_type="generic",
        actor_firebase_uid=None,
    )

    assert conn.execute.call_count == 1
    assert conn.execute.call_args.args[1][6] == ["on", "digest_user", "no_device"]
    assert [c.kwargs["firebase_uid"] for c in mock_push.call_args_list] == ["on"]
