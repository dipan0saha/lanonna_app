import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest

import httpx

from lanonna_worker.invite_email import (
    InviteSendOutcome,
    _render_invite_email,
    build_invite_url,
    send_invite_email,
)


def _sample_ctx(role: str) -> dict:
    return {
        "invitee_email": "guest@test.com",
        "role": role,
        "relationship_label": "Mom",
        "expires_at": datetime(2026, 12, 1, tzinfo=timezone.utc),
        "baby_name": "Parker",
        "inviter_display_name": "Alex",
    }


def test_build_invite_url_uses_https_landing_path():
    url = build_invite_url(
        "raw token/plus",
        "follower",
        base="https://lanonna-dev.firebaseapp.com",
    )
    assert url == (
        "https://lanonna-dev.firebaseapp.com/invite?token=raw%20token%2Fplus"
    )
    owner = build_invite_url(
        "tok",
        "owner",
        base="https://lanonna-dev.firebaseapp.com/",
    )
    assert owner == (
        "https://lanonna-dev.firebaseapp.com/invite?token=tok&role=owner"
    )


def test_build_invite_url_keeps_custom_scheme_for_explicit_override():
    assert (
        build_invite_url("abc", "follower", base="lanonna://app")
        == "lanonna://app/invite-accept?token=abc"
    )


def test_render_invite_email_follower_uses_follow_copy():
    subject, html, text = _render_invite_email(
        _sample_ctx("follower"),
        "lanonna://app/invite-accept?token=abc",
    )
    assert subject == "Alex invited you to Parker on La Nonna"
    assert "invited you to follow" in text
    assert "co-owner" not in text.lower()
    assert "invited you to follow" in html
    assert "co-owner" not in html.lower()


@pytest.mark.parametrize("stored", [None, "  "])
def test_render_invite_email_unnamed_baby_reads_their_baby(stored):
    for role, subject_text in (
        ("follower", "Alex invited you to their baby on La Nonna"),
        ("owner", "Alex invited you to co-manage their baby on La Nonna"),
    ):
        ctx = _sample_ctx(role)
        ctx["baby_name"] = stored
        subject, html, text = _render_invite_email(ctx, "https://x.example/invite?token=t")
        assert subject == subject_text
        assert "their baby's" in text
        assert "their baby's" in html
        assert "None" not in subject + html + text
        assert "Baby" not in subject


def test_render_invite_email_escapes_markup_names_for_both_roles():
    for role in ("follower", "owner"):
        ctx = _sample_ctx(role)
        ctx["inviter_display_name"] = '<a href="https://evil.example">Click</a>'
        ctx["baby_name"] = "A & B"
        ctx["relationship_label"] = 'Aunt "Bee"'
        _, html, text = _render_invite_email(
            ctx, "lanonna://app/invite-accept?token=abc"
        )
        assert '<a href="https://evil.example">' not in html
        assert "&lt;a href=&quot;https://evil.example&quot;&gt;" in html
        assert "A &amp; B" in html
        assert '<a href="https://evil.example">Click</a>' in text
        assert "A & B" in text
        assert 'Aunt "Bee"' in text


def test_render_invite_email_escapes_user_fields_in_html():
    ctx = _sample_ctx("follower")
    ctx["inviter_display_name"] = '<img src=x onerror="alert(1)">'
    ctx["baby_name"] = "<script>evil</script>"
    ctx["relationship_label"] = "<b>hack</b>"
    ctx["invitee_email"] = 'a"<@test.com'
    _, html, text = _render_invite_email(ctx, "lanonna://app/invite-accept?token=abc")
    assert "<img" not in html
    assert "<script>" not in html
    assert "&lt;img" in html
    assert "Relationship: &lt;b&gt;hack&lt;/b&gt;" in html
    assert 'a"&lt;@test.com' in html or "a&quot;&lt;@test.com" in html
    assert "<img" in text


def test_render_invite_email_owner_uses_coowner_copy():
    subject, html, text = _render_invite_email(
        _sample_ctx("owner"),
        "lanonna://app/invite-accept?token=abc&role=owner",
    )
    assert subject == "Alex invited you to co-manage Parker on La Nonna"
    assert "co-owner" in text
    assert "follow" not in text.lower()
    assert "co-owner" in html
    assert "invited you to follow" not in html


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_raises_when_mailjet_not_configured(mock_settings):
    mock_settings.mailjet_api_key = ""
    mock_settings.mailjet_api_secret = ""
    conn = MagicMock()
    with patch("lanonna_worker.invite_email.get_connection") as mock_conn_ctx:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        outcome = send_invite_email(uuid.uuid4())
    assert outcome == InviteSendOutcome.FAILED
    failed = [
        call
        for call in conn.execute.call_args_list
        if "email_delivery_status = 'failed'" in call[0][0]
    ]
    assert failed


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_skips_when_not_claimable(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = None
    with patch(
        "lanonna_worker.invite_email.get_connection"
    ) as mock_conn_ctx, patch("lanonna_worker.invite_email.httpx.post") as post:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        outcome = send_invite_email(uuid.uuid4())
    post.assert_not_called()
    assert outcome == InviteSendOutcome.SKIPPED


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_sends_and_marks_sent(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_settings.mailjet_from_email = "hello@test.com"
    mock_settings.mailjet_from_name = "La Nonna"
    mock_settings.invite_deep_link_base = "https://lanonna-dev.firebaseapp.com"
    inv_id = uuid.uuid4()
    ctx = {
        "invitee_email": "guest@test.com",
        "role": "follower",
        "relationship_label": None,
        "expires_at": __import__("datetime").datetime(
            2026, 12, 1, tzinfo=__import__("datetime").timezone.utc
        ),
        "email_invite_token": "invite-token",
        "baby_name": "Baby",
        "inviter_display_name": "Alex",
    }
    conn = MagicMock()
    call_count = 0

    def execute(sql, params=None):
        nonlocal call_count
        call_count += 1
        result = MagicMock()
        if "UPDATE invitations" in sql and "email_send_claimed_at = now()" in sql:
            result.fetchone.return_value = {"id": inv_id}
        elif "SELECT" in sql and "invitee_email" in sql:
            result.fetchone.return_value = ctx
        elif "email_sent_at = now()" in sql:
            result.fetchone.return_value = {"id": inv_id}
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"Messages": [{"Status": "success"}]}
    with patch(
        "lanonna_worker.invite_email.httpx.post",
        return_value=mock_response,
    ) as post, patch(
        "lanonna_worker.invite_email.get_connection"
    ) as mock_conn_ctx, patch(
        "lanonna_worker.invite_email.logger"
    ) as log:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        outcome = send_invite_email(inv_id)
    assert outcome == InviteSendOutcome.SENT
    sent = post.call_args.kwargs["json"]
    html = sent["Messages"][0]["HTMLPart"]
    assert "https://lanonna-dev.firebaseapp.com/invite?token=invite-token" in html
    assert "lanonna://" not in html
    logged = " ".join(str(call) for call in log.method_calls)
    assert "invite-token" not in logged
    assert call_count >= 2
    marked = [
        call
        for call in conn.execute.call_args_list
        if "email_sent_at = now()" in call[0][0]
    ]
    assert marked


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_connect_error_returns_retry_for_pubsub_backoff(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_settings.mailjet_from_email = "lanonnaapp@gmail.com"
    mock_settings.mailjet_from_name = "La Nonna"
    mock_settings.invite_deep_link_base = "https://lanonna-dev.firebaseapp.com"
    inv_id = uuid.uuid4()
    ctx = {
        "invitee_email": "guest@test.com",
        "role": "follower",
        "relationship_label": None,
        "expires_at": datetime(2026, 12, 1, tzinfo=timezone.utc),
        "email_invite_token": "invite-token",
        "baby_name": "Baby",
        "inviter_display_name": "Alex",
    }
    conn = MagicMock()

    def execute(sql, params=None):
        result = MagicMock()
        if "email_send_claimed_at = now()" in sql:
            result.fetchone.return_value = {"id": inv_id}
        elif "invitee_email" in sql:
            result.fetchone.return_value = ctx
        elif "email_sent_at = now()" in sql:
            result.fetchone.return_value = {"id": inv_id}
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute
    ok_response = MagicMock()
    ok_response.status_code = 200
    ok_response.json.return_value = {"Messages": [{"Status": "success"}]}
    with patch(
        "lanonna_worker.invite_email.httpx.post",
        side_effect=[httpx.ConnectError("reset"), ok_response],
    ) as post, patch(
        "lanonna_worker.invite_email.get_connection"
    ) as mock_conn_ctx:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        outcome = send_invite_email(inv_id, delivery_attempt=1, final_attempt=False)
    # No in-process retry: Pub/Sub redelivers with exponential backoff.
    assert outcome == InviteSendOutcome.RETRY
    assert post.call_count == 1


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_permanent_http_400_marks_failed(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_settings.mailjet_from_email = "lanonnaapp@gmail.com"
    mock_settings.mailjet_from_name = "La Nonna"
    mock_settings.invite_deep_link_base = "https://lanonna-dev.firebaseapp.com"
    inv_id = uuid.uuid4()
    ctx = {
        "invitee_email": "guest@test.com",
        "role": "follower",
        "relationship_label": None,
        "expires_at": datetime(2026, 12, 1, tzinfo=timezone.utc),
        "email_invite_token": "invite-token",
        "baby_name": "Baby",
        "inviter_display_name": "Alex",
    }
    conn = MagicMock()

    def execute(sql, params=None):
        result = MagicMock()
        if "email_send_claimed_at = now()" in sql:
            result.fetchone.return_value = {"id": inv_id}
        elif "invitee_email" in sql:
            result.fetchone.return_value = ctx
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute
    bad_response = MagicMock()
    bad_response.status_code = 400
    bad_response.text = "bad request"
    with patch(
        "lanonna_worker.invite_email.httpx.post",
        return_value=bad_response,
    ), patch(
        "lanonna_worker.invite_email.get_connection"
    ) as mock_conn_ctx:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        outcome = send_invite_email(inv_id, final_attempt=True)
    assert outcome == InviteSendOutcome.FAILED
    failed = [
        call
        for call in conn.execute.call_args_list
        if "email_delivery_status = 'failed'" in call[0][0]
    ]
    assert failed
    released = [
        call
        for call in conn.execute.call_args_list
        if "email_send_claimed_at = NULL" in call[0][0]
        and "email_delivery_status = 'failed'" not in call[0][0]
    ]
    assert released == []


@patch("lanonna_worker.invite_email.settings")
def test_send_invite_email_raises_on_mailjet_message_error(mock_settings):
    mock_settings.mailjet_api_key = "key"
    mock_settings.mailjet_api_secret = "secret"
    mock_settings.mailjet_from_email = "lanonnaapp@gmail.com"
    mock_settings.mailjet_from_name = "La Nonna"
    mock_settings.invite_deep_link_base = "https://lanonna-dev.firebaseapp.com"
    inv_id = uuid.uuid4()
    ctx = {
        "invitee_email": "guest@test.com",
        "role": "follower",
        "relationship_label": None,
        "expires_at": datetime(2026, 12, 1, tzinfo=timezone.utc),
        "email_invite_token": "invite-token",
        "baby_name": "Baby",
        "inviter_display_name": "Alex",
    }
    conn = MagicMock()

    def execute(sql, params=None):
        result = MagicMock()
        if "email_send_claimed_at = now()" in sql and "UPDATE" in sql:
            result.fetchone.return_value = {"id": inv_id}
        elif "invitee_email" in sql:
            result.fetchone.return_value = ctx
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "Messages": [
            {
                "Status": "error",
                "Errors": [{"ErrorCode": "mj-0013", "ErrorMessage": "sender"}],
            }
        ]
    }
    with patch(
        "lanonna_worker.invite_email.httpx.post",
        return_value=mock_response,
    ), patch(
        "lanonna_worker.invite_email.get_connection"
    ) as mock_conn_ctx:
        mock_conn_ctx.return_value.__enter__.return_value = conn
        outcome = send_invite_email(inv_id, final_attempt=True)
    assert outcome == InviteSendOutcome.FAILED
    marked = [
        call
        for call in conn.execute.call_args_list
        if "email_sent_at = now()" in call[0][0]
    ]
    assert marked == []
    failed = [
        call
        for call in conn.execute.call_args_list
        if "email_delivery_status = 'failed'" in call[0][0]
    ]
    assert failed
