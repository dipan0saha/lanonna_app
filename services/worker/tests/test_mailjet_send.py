from unittest.mock import MagicMock, patch

import httpx

from lanonna_worker.mailjet_send import (
    TRANSACTIONAL_TRACKING_DISABLED,
    build_send_payload,
    mailjet_message_error,
    post_mailjet,
    with_transactional_tracking,
)


def test_with_transactional_tracking_disables_click_and_open():
    message = {"Subject": "Hello", "To": [{"Email": "a@example.com"}]}
    enriched = with_transactional_tracking(message)
    assert enriched["TrackClicks"] == "disabled"
    assert enriched["TrackOpens"] == "disabled"
    assert enriched["Subject"] == "Hello"
    assert message.get("TrackClicks") is None


def test_build_send_payload_applies_tracking_to_every_message():
    payload = build_send_payload(
        [
            {"Subject": "One"},
            {"Subject": "Two"},
        ]
    )
    assert len(payload["Messages"]) == 2
    for message in payload["Messages"]:
        assert message["TrackClicks"] == TRANSACTIONAL_TRACKING_DISABLED["TrackClicks"]
        assert message["TrackOpens"] == TRANSACTIONAL_TRACKING_DISABLED["TrackOpens"]


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
def test_post_mailjet_uses_v31_send_endpoint(mock_post, mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_post.return_value = MagicMock(status_code=200)
    post_mailjet({"Messages": []})
    mock_post.assert_called_once()
    assert mock_post.call_args.args[0] == "https://api.mailjet.com/v3.1/send"
    assert mock_post.call_args.kwargs["auth"] == ("key", "secret")
    assert mock_post.call_args.kwargs["json"] == {"Messages": []}
    assert mock_post.call_args.kwargs["timeout"] == 30.0
