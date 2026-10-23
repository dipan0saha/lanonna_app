from unittest.mock import MagicMock, patch

import httpx

from lanonna_worker.mailjet_send import (
    TRANSACTIONAL_TRACKING_DISABLED,
    mailjet_message_error,
    send_messages,
    with_transactional_tracking,
)


def test_with_transactional_tracking_disables_click_and_open():
    message = {"Subject": "Hello", "To": [{"Email": "a@example.com"}]}
    enriched = with_transactional_tracking(message)
    assert enriched["TrackClicks"] == "disabled"
    assert enriched["TrackOpens"] == "disabled"
    assert enriched["Subject"] == "Hello"
    assert message.get("TrackClicks") is None


def test_mailjet_message_error_success_returns_none():
    response = MagicMock()
    response.json.return_value = {"Messages": [{"Status": "success"}]}
    assert mailjet_message_error(response) is None


def test_mailjet_message_error_surfaces_error_status():
    response = MagicMock()
    response.json.return_value = {
        "Messages": [
            {
                "Status": "error",
                "Errors": [{"ErrorCode": "mj-0013"}],
            }
        ]
    }
    assert "error" in mailjet_message_error(response)


@patch("lanonna_worker.mailjet_send.settings")
@patch("lanonna_worker.mailjet_send.httpx.post")
def test_send_messages_posts_v31_with_tracking_disabled_on_every_message(
    mock_post, mock_settings
):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_post.return_value = MagicMock(status_code=200)
    send_messages([{"Subject": "One"}, {"Subject": "Two", "TrackClicks": "enabled"}])
    mock_post.assert_called_once()
    assert mock_post.call_args.args[0] == "https://api.mailjet.com/v3.1/send"
    assert mock_post.call_args.kwargs["auth"] == ("key", "secret")
    timeout = mock_post.call_args.kwargs["timeout"]
    assert timeout.connect == 10.0
    assert timeout.read == 30.0
    messages = mock_post.call_args.kwargs["json"]["Messages"]
    assert [m["Subject"] for m in messages] == ["One", "Two"]
    for message in messages:
        assert message["TrackClicks"] == TRANSACTIONAL_TRACKING_DISABLED["TrackClicks"]
        assert message["TrackOpens"] == TRANSACTIONAL_TRACKING_DISABLED["TrackOpens"]


def test_no_other_module_calls_the_mailjet_api_directly():
    """Every Mailjet send must go through send_messages (#389)."""
    from pathlib import Path

    src = Path(__file__).resolve().parents[1] / "src" / "lanonna_worker"
    offenders = [
        p.name
        for p in src.rglob("*.py")
        if p.name != "mailjet_send.py" and "api.mailjet.com" in p.read_text()
    ]
    assert offenders == []


@patch("lanonna_worker.mailjet_send.mailjet_egress")
@patch("lanonna_worker.mailjet_send.httpx.post")
def test_send_messages_records_connect_failure_and_reraises(mock_post, mock_egress):
    mock_post.side_effect = httpx.ConnectError("[Errno 104] Connection reset by peer")
    try:
        send_messages([{"Subject": "One"}])
    except httpx.ConnectError:
        pass
    else:
        raise AssertionError("ConnectError must propagate to the caller's retry handling")
    mock_egress.record_connect_failure.assert_called_once()
    mock_egress.record_reachable.assert_not_called()


@patch("lanonna_worker.mailjet_send.mailjet_egress")
@patch("lanonna_worker.mailjet_send.httpx.post")
def test_send_messages_any_http_response_marks_egress_reachable(mock_post, mock_egress):
    mock_post.return_value = MagicMock(status_code=503)
    send_messages([{"Subject": "One"}])
    mock_egress.record_reachable.assert_called_once()
    mock_egress.record_connect_failure.assert_not_called()


@patch("lanonna_worker.mailjet_send.mailjet_egress")
@patch("lanonna_worker.mailjet_send.httpx.post")
def test_send_messages_read_timeout_is_not_an_egress_failure(mock_post, mock_egress):
    mock_post.side_effect = httpx.ReadTimeout("slow")
    try:
        send_messages([{"Subject": "One"}])
    except httpx.ReadTimeout:
        pass
    mock_egress.record_connect_failure.assert_not_called()
