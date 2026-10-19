"""HTTP contract of the unauthenticated biometric sign-in routes."""

import uuid
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.domain.errors import ErrorCode, UnauthenticatedError
from lanonna_api.main import app

client = TestClient(app)


def test_challenge_rejects_malformed_credential_id_without_touching_sql():
    with patch("lanonna_api.routers.biometric_auth.issue_biometric_challenge") as issue:
        response = client.post(
            "/v1/auth/biometric/challenge",
            json={"credential_id": "x" * 36},
        )
    assert response.status_code == 422
    issue.assert_not_called()


def test_invalid_credential_uses_one_opaque_code():
    with patch(
        "lanonna_api.routers.biometric_auth.issue_biometric_challenge",
        side_effect=UnauthenticatedError(ErrorCode.BIOMETRIC_CREDENTIAL_INVALID, "x"),
    ):
        response = client.post(
            "/v1/auth/biometric/challenge",
            json={"credential_id": str(uuid.uuid4())},
        )
    assert response.status_code == 401
    assert response.json()["detail"]["error"] == "biometric_credential_invalid"


def test_sign_in_returns_only_the_custom_token():
    with patch(
        "lanonna_api.routers.biometric_auth.complete_biometric_sign_in",
        return_value={"custom_token": "tok"},
    ):
        response = client.post(
            "/v1/auth/biometric/sign-in",
            json={
                "credential_id": str(uuid.uuid4()),
                "challenge_id": str(uuid.uuid4()),
                "signature": "MEUCIQ" + "A" * 60,
            },
        )
    assert response.status_code == 200
    assert response.json() == {"custom_token": "tok"}


def test_enroll_rejects_unknown_algorithm():
    from lanonna_api.auth import current_user

    app.dependency_overrides[current_user] = lambda: {"uid": "user-1", "email": "u@test.com"}
    try:
        response = client.post(
            "/v1/me/biometric-credentials",
            json={
                "device_id": "d" * 32,
                "public_key_pem": "-----BEGIN PUBLIC KEY-----\n" + "A" * 40,
                "algorithm": "rsa_sha256",
            },
        )
    finally:
        app.dependency_overrides.pop(current_user, None)
    assert response.status_code == 422
