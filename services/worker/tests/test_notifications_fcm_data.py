import uuid
from unittest.mock import MagicMock, patch

from lanonna_worker.notifications import _send_fcm


@patch("lanonna_worker.notifications.messaging.send_each_for_multicast")
@patch("lanonna_worker.notifications._list_fcm_tokens", return_value=["tok1"])
@patch("lanonna_worker.notifications._user_push_prefs", return_value=(True, "realtime"))
@patch("lanonna_worker.notifications._ensure_fcm")
def test_send_fcm_includes_baby_profile_id(
    _ensure,
    _prefs,
    _tokens,
    mock_send,
):
    mock_send.return_value = MagicMock(responses=[MagicMock(success=True)])
    conn = MagicMock()
    baby_id = uuid.uuid4()
    nid = uuid.uuid4()

    _send_fcm(
        conn,
        firebase_uid="u1",
        title="T",
        body="B",
        deep_link="/gallery/photo/x",
        notification_id=nid,
        baby_profile_id=baby_id,
    )

    message = mock_send.call_args[0][0]
    assert message.data["deep_link"] == "/gallery/photo/x"
    assert message.data["notification_id"] == str(nid)
    assert message.data["baby_profile_id"] == str(baby_id)
