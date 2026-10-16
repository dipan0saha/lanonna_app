from types import MappingProxyType
import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.invitations import BatchInviteRow, batch_invite
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


def test_batch_invite_reenqueues_pending_undelivered_invite():
    baby_id = uuid.uuid4()
    pending_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch("lanonna_api.domain.invitations.email_is_member", return_value=False),
        patch(
            "lanonna_api.domain.invitations.fetch_pending_invitation_by_email",
            return_value={
                "id": pending_id,
                "email_sent_at": None,
                "email_delivery_status": "failed",
            },
        ),
        patch(
            "lanonna_api.domain.invitations.prepare_invitation_for_resend",
            return_value={"id": pending_id, "invitee_email": "a@test.com"},
        ),
        patch(
            "lanonna_api.domain.invitations.publish_send_invite_email",
        ) as publish,
    ):
        results = batch_invite(
            "owner-1",
            baby_id,
            [BatchInviteRow("a@test.com", "follower", None)],
        )
    assert results[0]["status"] == "resent"
    assert results[0]["invitation_id"] == pending_id
    publish.assert_called_once_with(pending_id)


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
