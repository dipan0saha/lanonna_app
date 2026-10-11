import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.main import app

client = TestClient(app)

_ENDED = MemberLifecycleError(
    "membership_ended",
    "You no longer have access to this baby profile.",
)


@contextmanager
def _auth_as(uid: str = "member-1"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": "m@test.com"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_search_membership_ended_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.search.upsert_app_user"),
        patch(
            "lanonna_api.routers.search.search_baby_content",
            side_effect=_ENDED,
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/search?q=foo")
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "membership_ended"


def test_list_invitations_membership_ended_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.invitations.upsert_app_user"),
        patch(
            "lanonna_api.routers.invitations.list_invitations_for_owner",
            side_effect=_ENDED,
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/invitations")
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "membership_ended"


def test_list_members_membership_ended_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.members.upsert_app_user"),
        patch(
            "lanonna_api.routers.members.list_members_for_owner",
            side_effect=_ENDED,
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/members")
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "membership_ended"


def test_first_moment_seed_membership_ended_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.babies.upsert_app_user"),
        patch(
            "lanonna_api.routers.babies.seed_first_moment",
            side_effect=_ENDED,
        ),
    ):
        response = client.post(
            f"/v1/babies/{baby_id}/onboarding/first-moment",
            json={
                "event_preset_ids": [],
                "registry_preset_ids": [],
                "name_suggestions": [],
            },
        )
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "membership_ended"
