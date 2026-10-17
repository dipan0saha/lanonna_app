from types import MappingProxyType
import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "owner-1"):
    app.dependency_overrides[current_app_user] = lambda: AppUser(
        uid=uid,
        email="o@test.com",
        display_name=None,
        claims=MappingProxyType({"uid": uid}),
    )
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_app_user, None)


def test_resend_invitation_route_returns_204():
    baby_id = uuid.uuid4()
    inv_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.routers.invitations.resend_invitation_for_owner",
        ) as resend,
        _auth_as(),
    ):
        response = client.post(
            f"/v1/babies/{baby_id}/invitations/{inv_id}/resend",
        )
    assert response.status_code == 204
    resend.assert_called_once_with("owner-1", baby_id, inv_id)


def test_resend_invitation_not_found_returns_404():
    baby_id = uuid.uuid4()
    inv_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.routers.invitations.resend_invitation_for_owner",
            side_effect=LookupError("Invitation not found"),
        ),
        _auth_as(),
    ):
        response = client.post(
            f"/v1/babies/{baby_id}/invitations/{inv_id}/resend",
        )
    assert response.status_code == 404
