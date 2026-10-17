import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.domain.errors import ErrorCode, ForbiddenError, GoneError, NotFoundError
from lanonna_api.domain.owner_limit import MaxOwnersError
from lanonna_api.main import app

client = TestClient(app)


@contextmanager
def _auth_as(uid: str = "invitee-1", email: str = "invitee@test.com"):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": email}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_invitation_accept_success():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.invitations.accept_invitation_by_token",
            return_value={
                "already_member": False,
                "baby_profile_id": baby_id,
                "role": "follower",
                "baby_name": "Baby",
                "inviter_firebase_uid": "owner-1",
            },
        ),
        patch(
            "lanonna_api.domain.invitations.safe_enqueue_notify_user",
        ) as notify,
    ):
        response = client.post(
            "/v1/invitations/accept",
            json={"token": "a" * 12},
        )
    assert response.status_code == 200
    assert response.json()["baby_profile_id"] == str(baby_id)
    notify.assert_called_once()


def test_invitation_preview_not_found_returns_structured_detail():
    with patch(
        "lanonna_api.routers.invitation_accept.preview_invitation",
        return_value=None,
    ):
        response = client.get("/v1/invitations/preview?token=abcdefghijkl")
    assert response.status_code == 404
    assert response.json()["detail"]["error"] == "not_found"


def test_invitation_accept_not_found_returns_404():
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.invitations.accept_invitation_by_token",
            side_effect=NotFoundError(ErrorCode.NOT_FOUND, "Invitation not found"),
        ),
    ):
        response = client.post(
            "/v1/invitations/accept",
            json={"token": "b" * 12},
        )
    assert response.status_code == 404
    assert response.json()["detail"]["error"] == "not_found"


def test_invitation_accept_email_mismatch_returns_403_with_emails():
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.invitations.accept_invitation_by_token",
            side_effect=ForbiddenError(
                ErrorCode.EMAIL_MISMATCH,
                "Signed-in email does not match the invitation",
                params={
                    "invitee_email": "invited@test.com",
                    "signed_in_email": "other@test.com",
                },
            ),
        ),
    ):
        response = client.post(
            "/v1/invitations/accept",
            json={"token": "c" * 12},
        )
    assert response.status_code == 403
    detail = response.json()["detail"]
    assert detail["error"] == "email_mismatch"
    assert detail["params"] == {
        "invitee_email": "invited@test.com",
        "signed_in_email": "other@test.com",
    }


def test_invitation_accept_notify_enqueue_failure_still_200():
    baby_id = uuid.uuid4()
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.invitations.accept_invitation_by_token",
            return_value={
                "already_member": False,
                "baby_profile_id": baby_id,
                "role": "follower",
                "baby_name": "Baby",
                "inviter_firebase_uid": "owner-1",
            },
        ),
        patch(
            "lanonna_api.domain.invitations.safe_enqueue_notify_user",
        ) as notify,
    ):
        response = client.post(
            "/v1/invitations/accept",
            json={"token": "d" * 12},
        )
    assert response.status_code == 200
    notify.assert_called_once()


def test_invitation_accept_refusals_map_through_domain_errors():
    cases = [
        (GoneError(ErrorCode.EXPIRED, "Invitation expired"), 410, "expired"),
        (GoneError(ErrorCode.REVOKED, "Invitation revoked"), 410, "revoked"),
        (MaxOwnersError(), 409, "max_owners"),
    ]
    for error, status_code, code in cases:
        with (
            _auth_as(),
            patch(
                "lanonna_api.domain.invitations.accept_invitation_by_token",
                side_effect=error,
            ),
        ):
            response = client.post("/v1/invitations/accept", json={"token": "e" * 12})
        assert response.status_code == status_code
        assert response.json()["detail"]["error"] == code
