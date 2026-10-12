from unittest.mock import MagicMock, patch

from firebase_admin import messaging

from lanonna_worker.notifications import (
    _chunk_tokens,
    _send_multicast_and_prune_tokens,
)


def test_chunk_tokens_splits_at_500():
    tokens = [f"t{i}" for i in range(501)]
    chunks = _chunk_tokens(tokens)
    assert len(chunks) == 2
    assert len(chunks[0]) == 500
    assert len(chunks[1]) == 1


@patch("lanonna_worker.notifications.messaging.send_each_for_multicast")
@patch("lanonna_worker.notifications._ensure_fcm")
def test_multicast_chunks_large_token_lists(mock_ensure, mock_send):
    tokens = [f"t{i}" for i in range(501)]
    mock_send.return_value = MagicMock(responses=[])

    def build(chunk: list[str]) -> messaging.MulticastMessage:
        return messaging.MulticastMessage(tokens=chunk)

    _send_multicast_and_prune_tokens(MagicMock(), tokens, build)
    assert mock_send.call_count == 2


@patch("lanonna_worker.notifications._delete_fcm_token")
@patch("lanonna_worker.notifications.messaging.send_each_for_multicast")
@patch("lanonna_worker.notifications._ensure_fcm")
def test_multicast_does_not_delete_on_transient_error(mock_ensure, mock_send, mock_delete):
    conn = MagicMock()
    bad = MagicMock(success=False, exception=RuntimeError("temporary"))
    mock_send.return_value = MagicMock(responses=[bad])

    def build(chunk: list[str]) -> messaging.MulticastMessage:
        return messaging.MulticastMessage(tokens=chunk)

    _send_multicast_and_prune_tokens(conn, ["tok1"], build, log_uid="uid1")
    mock_delete.assert_not_called()


@patch("lanonna_worker.notifications._delete_fcm_token")
@patch("lanonna_worker.notifications.messaging.send_each_for_multicast")
@patch("lanonna_worker.notifications._ensure_fcm")
def test_multicast_deletes_unregistered_tokens(mock_ensure, mock_send, mock_delete):
    conn = MagicMock()
    bad = MagicMock(
        success=False,
        exception=messaging.UnregisteredError("gone"),
    )
    mock_send.return_value = MagicMock(responses=[bad])

    def build(chunk: list[str]) -> messaging.MulticastMessage:
        return messaging.MulticastMessage(tokens=chunk)

    _send_multicast_and_prune_tokens(conn, ["tok1"], build, log_uid="uid1")
    mock_delete.assert_called_once_with(conn, "tok1")
