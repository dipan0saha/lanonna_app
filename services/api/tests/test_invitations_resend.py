from types import MappingProxyType
import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.errors import ConflictError, ErrorCode, NotFoundError
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


def test_resend_invitation_already_delivered_returns_409():
    baby_id = uuid.uuid4()
    inv_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.routers.invitations.resend_invitation_for_owner",
            side_effect=ConflictError(
                ErrorCode.INVITE_ALREADY_DELIVERED,
                "Invite email was already delivered",
            ),
        ),
        _auth_as(),
    ):
        response = client.post(
            f"/v1/babies/{baby_id}/invitations/{inv_id}/resend",
        )
    assert response.status_code == 409
    assert response.json()["detail"]["error"] == "invite_already_delivered"


def test_resend_invitation_not_found_returns_404():
    baby_id = uuid.uuid4()
    inv_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.routers.invitations.resend_invitation_for_owner",
            side_effect=NotFoundError(ErrorCode.NOT_FOUND, "Invitation not found"),
        ),
        _auth_as(),
    ):
        response = client.post(
            f"/v1/babies/{baby_id}/invitations/{inv_id}/resend",
        )
    assert response.status_code == 404


def _resend_domain(prep: str):
    from lanonna_api.domain import invitations as domain

    with (
        patch.object(domain, "require_owner_baby"),
        patch.object(domain, "prepare_invitation_for_resend", return_value=prep),
        patch.object(domain, "_enqueue_invite_email") as enqueue,
    ):
        try:
            domain.resend_invitation_for_owner("owner-1", uuid.uuid4(), uuid.uuid4())
        except Exception as exc:  # noqa: BLE001 - returned for assertions
            return exc, enqueue
    return None, enqueue


def test_resend_domain_prepared_enqueues_send():
    exc, enqueue = _resend_domain("prepared")
    assert exc is None
    enqueue.assert_called_once()


def test_resend_domain_already_delivered_is_conflict():
    exc, enqueue = _resend_domain("already_delivered")
    assert isinstance(exc, ConflictError)
    assert exc.code == ErrorCode.INVITE_ALREADY_DELIVERED
    enqueue.assert_not_called()


def test_resend_domain_missing_is_not_found():
    exc, enqueue = _resend_domain("not_found")
    assert isinstance(exc, NotFoundError)
    enqueue.assert_not_called()
