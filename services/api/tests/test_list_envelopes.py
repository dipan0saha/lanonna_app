"""Babies, members, invitations and registry lists page in SQL and return the envelope."""

import uuid
from contextlib import contextmanager
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app
from lanonna_api.repositories._paging import limit_offset_clause

client = TestClient(app)
BABY = uuid.uuid4()


@contextmanager
def as_user(uid: str = "owner-1"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": "o@test.com"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_limit_offset_clause():
    assert limit_offset_clause(None, 0) == ("", ())
    assert limit_offset_clause(3, 6) == ("LIMIT %s OFFSET %s", (3, 6))


def _member(i: int) -> dict:
    return {
        "firebase_uid": f"u{i}",
        "display_name": "A",
        "role": "follower",
        "can_remove": True,
        "created_at": "2026-01-01T00:00:00+00:00",
    }


def _invitation(i: int) -> dict:
    return {
        "id": uuid.uuid4(),
        "invitee_email": "x@test.com",
        "role": "follower",
        "relationship_label": None,
        "status": "pending",
        "expires_at": None,
        "created_at": None,
        "email_sent_at": None,
        "email_delivery_status": None,
        "email_last_error": None,
        "email_send_attempts": 0,
    }


@pytest.mark.parametrize(
    ("path", "target", "row"),
    [
        (f"/v1/babies/{BABY}/members", "lanonna_api.routers.members.list_members_for_owner", _member),
        (
            f"/v1/babies/{BABY}/invitations",
            "lanonna_api.routers.invitations.list_invitations_for_owner",
            _invitation,
        ),
        (
            f"/v1/babies/{BABY}/registry/items",
            "lanonna_api.domain.registry.list_items",
            lambda i: {"id": str(i)},
        ),
    ],
)
def test_baby_scoped_lists_fetch_one_extra_row(path, target, row):
    with as_user(), patch(target, return_value=[row(i) for i in range(3)]) as fetch:
        resp = client.get(f"{path}?limit=2&offset=4")
    assert resp.status_code == 200
    assert fetch.call_args.kwargs == {"limit": 3, "offset": 4}
    body = resp.json()
    assert (body["offset"], body["limit"], body["has_more"]) == (4, 2, True)
    assert len(body["items"]) == 2


def test_list_babies_envelope_builds_summaries_from_list_rows_only():
    rows = [{"id": uuid.uuid4(), "role": "owner", "active_owner_count": 1} for _ in range(3)]
    summary = SimpleNamespace(model_dump=lambda mode: {"id": "b"})
    with (
        as_user(),
        patch("lanonna_api.routers.babies.list_babies_for_user", return_value=rows) as fetch,
        patch("lanonna_api.routers.babies.baby_summary_from_row", return_value=summary) as build,
    ):
        resp = client.get("/v1/babies?limit=2")
    assert resp.status_code == 200
    assert fetch.call_args.kwargs == {"limit": 3, "offset": 0}
    # Owner counts arrive on the list rows; no follow-up query per baby, and
    # the extra has_more probe row is never summarised.
    assert [c.args[0] for c in build.call_args_list] == rows[:2]
    body = resp.json()
    assert body["has_more"] is True and len(body["items"]) == 2


def test_list_limit_is_capped():
    with as_user():
        assert client.get("/v1/babies?limit=101").status_code == 422
