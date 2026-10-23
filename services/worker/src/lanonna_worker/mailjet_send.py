"""Shared Mailjet v3.1 send layer for transactional email."""

from __future__ import annotations

from typing import Any

import httpx

from lanonna_worker.config import settings

# Invite tokens, export links, and similar URLs must not pass through Mailjet
# click/open trackers (account defaults otherwise rewrite hrefs to mjt.lu).
TRANSACTIONAL_TRACKING_DISABLED: dict[str, str] = {
    "TrackClicks": "disabled",
    "TrackOpens": "disabled",
}

_MAILJET_SEND_URL = "https://api.mailjet.com/v3.1/send"


def with_transactional_tracking(message: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of a Mailjet message with link/open tracking disabled."""
    return {**message, **TRANSACTIONAL_TRACKING_DISABLED}


def build_send_payload(messages: list[dict[str, Any]]) -> dict[str, Any]:
    """Wrap messages for POST /v3.1/send with transactional tracking defaults."""
    return {
        "Messages": [with_transactional_tracking(message) for message in messages],
    }


def post_mailjet(payload: dict[str, Any]) -> httpx.Response:
    return httpx.post(
        _MAILJET_SEND_URL,
        auth=(settings.mailjet_api_key, settings.mailjet_api_secret),
        json=payload,
        timeout=30.0,
    )


def mailjet_message_error(response: httpx.Response) -> str | None:
    """Mailjet can return HTTP 200 with Messages[0].Status == error (#43)."""
    try:
        body = response.json()
    except Exception:
        return "Mailjet response was not JSON"
    messages = body.get("Messages") if isinstance(body, dict) else None
    if not isinstance(messages, list) or not messages or not isinstance(messages[0], dict):
        return "Mailjet response missing Messages"
    status = messages[0].get("Status")
    if status == "success":
        return None
    codes: list[str] = []
    errors = messages[0].get("Errors") or []
    if isinstance(errors, list):
        for err in errors:
            if isinstance(err, dict) and err.get("ErrorCode"):
                codes.append(str(err["ErrorCode"]))
    code = ",".join(codes) if codes else "unknown"
    return f"Mailjet message status={status} error_code={code}"
