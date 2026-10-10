import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "member-1"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": "m@test.com"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_home_summary_membership_ended_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.babies.upsert_app_user"),
        patch(
            "lanonna_api.routers.babies.build_home_summary",
            side_effect=MemberLifecycleError(
                "membership_ended",
                "You no longer have access to this baby profile.",
            ),
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/home-summary")
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "membership_ended"


def test_activity_events_membership_ended_returns_403():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch("lanonna_api.routers.babies.upsert_app_user"),
        patch(
            "lanonna_api.routers.babies.list_activity_events",
            side_effect=MemberLifecycleError(
                "membership_ended",
                "You no longer have access to this baby profile.",
            ),
        ),
    ):
        response = client.get(f"/v1/babies/{baby_id}/activity-events")
    assert response.status_code == 403
    assert response.json()["detail"]["error"] == "membership_ended"
