from __future__ import annotations

from datetime import datetime, timedelta, timezone
import base64
import json
from types import MappingProxyType
from contextlib import contextmanager
from unittest.mock import patch
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.errors import ErrorCode
from lanonna_api.main import app
from lanonna_api.pagination import decode_created_at_id_cursor, encode_created_at_id_cursor

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "user-1"):
    app.dependency_overrides[current_app_user] = lambda: AppUser(
        uid=uid,
        email="u@test.com",
        display_name=None,
        claims=MappingProxyType({"uid": uid}),
    )
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_app_user, None)


def _row(created_at: datetime, row_id: UUID | None = None) -> dict:
    return {
        "id": row_id or uuid4(),
        "baby_profile_id": None,
        "title": "Hi",
        "body": "There",
        "deep_link": "/home",
        "notification_type": "generic",
        "notification_kind": None,
        "params": {},
        "actor_firebase_uid": None,
        "actor_display_name": None,
        "read_at": None,
        "created_at": created_at,
    }


def test_cursor_round_trip():
    now = datetime.now(timezone.utc)
    row_id = uuid4()
    token = encode_created_at_id_cursor(now, row_id)
    decoded_at, decoded_id = decode_created_at_id_cursor(token)
    assert decoded_id == row_id
    assert decoded_at == now


@patch("lanonna_api.routers.notifications.list_notifications_for_user")
def test_list_notifications_first_page_returns_cursor_envelope(mock_list):
    base = datetime(2026, 10, 1, 12, tzinfo=timezone.utc)
    rows = [_row(base - timedelta(hours=i), uuid4()) for i in range(3)]
    mock_list.return_value = rows
    with _auth_as():
        response = client.get("/v1/me/notifications?limit=2")
    assert response.status_code == 200
    payload = response.json()
    assert set(payload.keys()) == {"items", "limit", "has_more", "next_cursor"}
    assert payload["limit"] == 2
    assert payload["has_more"] is True
    assert len(payload["items"]) == 2
    assert payload["next_cursor"] is not None
    mock_list.assert_called_once()
    _, kwargs = mock_list.call_args
    assert kwargs["limit"] == 3
    assert kwargs["after"] is None


@patch("lanonna_api.routers.notifications.list_notifications_for_user")
def test_list_notifications_second_page_uses_decoded_cursor(mock_list):
    base = datetime(2026, 10, 1, 12, tzinfo=timezone.utc)
    id_a, id_b = uuid4(), uuid4()
    rows = [_row(base, id_a), _row(base - timedelta(hours=1), id_b)]
    mock_list.return_value = rows
    cursor = encode_created_at_id_cursor(base, id_a)
    with _auth_as():
        response = client.get(f"/v1/me/notifications?limit=1&cursor={cursor}")
    assert response.status_code == 200
    payload = response.json()
    assert len(payload["items"]) == 1
    mock_list.assert_called_once()
    _, kwargs = mock_list.call_args
    assert kwargs["after"] == (base, id_a)


@patch("lanonna_api.routers.notifications.list_notifications_for_user")
def test_cursor_pages_do_not_overlap(mock_list):
    """Simulate stable ordering: page 2 starts strictly after page 1 tail."""
    base = datetime(2026, 10, 5, 8, tzinfo=timezone.utc)
    ids = [uuid4() for _ in range(5)]
    all_rows = [_row(base - timedelta(minutes=i), ids[i]) for i in range(5)]

    def fetch(**kwargs):
        limit = kwargs["limit"]
        after = kwargs.get("after")
        filtered = all_rows
        if after is not None:
            filtered = [r for r in all_rows if (r["created_at"], r["id"]) < after]
        return filtered[:limit]

    mock_list.side_effect = lambda firebase_uid, **kwargs: fetch(**kwargs)

    seen: list[str] = []
    cursor = None
    with _auth_as():
        for _ in range(3):
            path = "/v1/me/notifications?limit=2"
            if cursor:
                path += f"&cursor={cursor}"
            payload = client.get(path).json()
            for item in payload["items"]:
                seen.append(item["id"])
            if not payload["has_more"]:
                break
            cursor = payload["next_cursor"]
    assert seen == [str(i) for i in ids]
    assert len(seen) == len(set(seen))


def _b64(payload: object) -> str:
    raw = json.dumps(payload).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


@pytest.mark.parametrize(
    "token",
    [
        "not-base64!!",
        _b64(["2026-10-01T12:00:00+00:00", str(uuid4())]),
        _b64({"created_at": "2026-10-01T12:00:00", "id": str(uuid4())}),
        _b64({"created_at": "2026-10-01T12:00:00+00:00", "id": "nope"}),
        _b64({"id": str(uuid4())}),
        "A" * 500,
    ],
    ids=["garbage", "not-object", "naive-time", "bad-id", "missing-key", "too-long"],
)
@patch("lanonna_api.routers.notifications.list_notifications_for_user")
def test_malformed_cursor_is_400_and_never_queries(mock_list, token):
    with pytest.raises(ValueError):
        decode_created_at_id_cursor(token)
    with _auth_as():
        response = client.get(f"/v1/me/notifications?cursor={token}")
    assert response.status_code == 400
    assert response.json()["detail"]["error"] == ErrorCode.INVALID_REQUEST.value
    mock_list.assert_not_called()


@patch("lanonna_api.routers.notifications.list_notifications_for_user")
def test_legacy_client_without_cursor_gets_first_page(mock_list):
    """Pre-cursor app builds call the endpoint bare and read only ``items``."""
    mock_list.return_value = [_row(datetime(2026, 10, 1, tzinfo=timezone.utc))]
    with _auth_as():
        response = client.get("/v1/me/notifications")
    assert response.status_code == 200
    assert len(response.json()["items"]) == 1
    _, kwargs = mock_list.call_args
    assert kwargs == {"limit": 51, "after": None}
