import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest

from lanonna_worker.invite_email import _render_invite_email, send_invite_email


def _sample_ctx(role: str) -> dict:
    return {
        "invitee_email": "guest@test.com",
        "role": role,
        "relationship_label": "Mom",
        "expires_at": datetime(2026, 12, 1, tzinfo=timezone.utc),
        "baby_name": "Baby",
        "inviter_display_name": "Alex",
    }


def test_render_invite_email_follower_uses_follow_copy():
    subject, html, text = _render_invite_email(
        _sample_ctx("follower"),
        "lanonna://app/invite-accept?token=abc",
    )
    assert subject == "Alex invited you to Baby on La Nonna"
    assert "invited you to follow" in text
    assert "co-owner" not in text.lower()
    assert "invited you to follow" in html
    assert "co-owner" not in html.lower()


def test_render_invite_email_owner_uses_coowner_copy():
    subject, html, text = _render_invite_email(
        _sample_ctx("owner"),
        "lanonna://app/invite-accept?token=abc&role=owner",
    )
    assert subject == "Alex invited you to co-manage Baby on La Nonna"
    assert "co-owner" in text
    assert "follow" not in text.lower()
    assert "co-owner" in html
    assert "invited you to follow" not in html


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_raises_when_mailjet_not_configured(mock_settings):
    mock_settings.mailjet_api_key = ""
    mock_settings.mailjet_api_secret = ""
    with pytest.raises(RuntimeError, match="Mailjet is not configured"):
        send_invite_email(uuid.uuid4(), "token")


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_skips_when_not_pending(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    with patch(
        "lanonna_worker.invite_email._fetch_email_context",
        return_value=None,
    ), patch("lanonna_worker.invite_email.httpx.post") as post:
        send_invite_email(uuid.uuid4(), "token")
    post.assert_not_called()


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_sends_and_marks_sent(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_settings.mailjet_from_email = "hello@test.com"
    mock_settings.mailjet_from_name = "La Nonna"
    inv_id = uuid.uuid4()
    ctx = {
        "invitee_email": "guest@test.com",
        "role": "follower",
        "relationship_label": None,
        "expires_at": __import__("datetime").datetime(
            2026, 12, 1, tzinfo=__import__("datetime").timezone.utc
        ),
        "baby_name": "Baby",
        "inviter_display_name": "Alex",
    }
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = {"id": inv_id}
    mock_response = MagicMock()
    mock_response.status_code = 200
    with patch(
        "lanonna_worker.invite_email._fetch_email_context",
        return_value=ctx,
    ), patch(
        "lanonna_worker.invite_email.httpx.post",
        return_value=mock_response,
    ), patch(
        "lanonna_worker.invite_email.get_connection"
    ) as mock_conn_ctx:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        send_invite_email(inv_id, "invite-token")
    conn.execute.assert_called()
