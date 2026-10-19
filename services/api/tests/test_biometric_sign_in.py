"""Unit tests for biometric challenge-response sign-in."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

from lanonna_api.domain.biometric_sign_in import (
    complete_biometric_sign_in,
    enroll_biometric_credential,
    issue_biometric_challenge,
)
from lanonna_api.domain.errors import ErrorCode, GoneError


def _ec_keypair():
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    return private_key, public_pem


def _sign(private_key, payload: str) -> str:
    import base64

    sig = private_key.sign(payload.encode(), ec.ECDSA(hashes.SHA256()))
    return base64.b64encode(sig).decode()


@patch("lanonna_api.domain.biometric_sign_in.register_credential")
def test_enroll_delegates(mock_register):
    mock_register.return_value = {"id": "cred-1", "created_at": "t"}
    _, pub = _ec_keypair()
    out = enroll_biometric_credential("uid", "device-1", pub, "ECDSA_SHA256")
    assert out["id"] == "cred-1"
    mock_register.assert_called_once()


@patch("lanonna_api.domain.biometric_sign_in.get_active_credential")
@patch("lanonna_api.domain.biometric_sign_in.create_challenge")
def test_issue_challenge(mock_create, mock_get):
    mock_get.return_value = {
        "id": "cred",
        "revoked_at": None,
        "deleted_at": None,
    }
    mock_create.return_value = {
        "challenge_id": "ch",
        "nonce": "n",
        "expires_at": "t",
    }
    result = issue_biometric_challenge("cred")
    assert result["nonce"] == "n"


@patch("lanonna_api.domain.biometric_sign_in.firebase_auth.create_custom_token")
@patch("lanonna_api.domain.biometric_sign_in.firebase_auth.get_user")
@patch("lanonna_api.domain.biometric_sign_in.mark_credential_used")
@patch("lanonna_api.domain.biometric_sign_in.consume_challenge")
@patch("lanonna_api.domain.biometric_sign_in.get_active_credential")
def test_complete_sign_in_success(
    mock_get_cred,
    mock_consume,
    mock_mark,
    mock_get_user,
    mock_token,
):
    private_key, pub = _ec_keypair()
    created = datetime.now(timezone.utc) - timedelta(days=1)
    mock_get_cred.return_value = {
        "firebase_uid": "uid-1",
        "revoked_at": None,
        "deleted_at": None,
        "public_key_pem": pub,
        "algorithm": "ECDSA_SHA256",
        "created_at": created,
    }
    mock_consume.return_value = "nonce-abc"
    mock_get_user.return_value = MagicMock(tokens_valid_after_timestamp=None)
    mock_token.return_value = b"tok"

    sig = _sign(private_key, "nonce-abc")
    out = complete_biometric_sign_in("cred-id", "ch-id", sig)
    assert out["custom_token"] == "tok"
    assert out["firebase_uid"] == "uid-1"
    mock_mark.assert_called_once()


@patch("lanonna_api.domain.biometric_sign_in.get_active_credential")
def test_complete_sign_in_revoked_credential(mock_get):
    mock_get.return_value = {
        "revoked_at": datetime.now(timezone.utc),
        "deleted_at": None,
    }
    with pytest.raises(GoneError) as exc:
        complete_biometric_sign_in("c", "ch", "sig")
    assert exc.value.code == ErrorCode.REVOKED


@patch("lanonna_api.domain.biometric_sign_in.firebase_auth.get_user")
@patch("lanonna_api.domain.biometric_sign_in.consume_challenge")
@patch("lanonna_api.domain.biometric_sign_in.get_active_credential")
def test_complete_sign_in_expired_challenge(mock_get, mock_consume, mock_get_user):
    _, pub = _ec_keypair()
    mock_get.return_value = {
        "firebase_uid": "uid",
        "revoked_at": None,
        "deleted_at": None,
        "public_key_pem": pub,
        "algorithm": "ECDSA_SHA256",
        "created_at": datetime.now(timezone.utc),
    }
    mock_consume.return_value = None
    mock_get_user.return_value = MagicMock(tokens_valid_after_timestamp=None)
    with pytest.raises(GoneError) as exc:
        complete_biometric_sign_in("c", "ch", "sig")
    assert exc.value.code == ErrorCode.EXPIRED


@patch("lanonna_api.domain.biometric_sign_in.firebase_auth.get_user")
@patch("lanonna_api.domain.biometric_sign_in.consume_challenge")
@patch("lanonna_api.domain.biometric_sign_in.get_active_credential")
def test_complete_sign_in_bad_signature(mock_get, mock_consume, mock_get_user):
    _, pub = _ec_keypair()
    mock_get.return_value = {
        "firebase_uid": "uid",
        "revoked_at": None,
        "deleted_at": None,
        "public_key_pem": pub,
        "algorithm": "ECDSA_SHA256",
        "created_at": datetime.now(timezone.utc),
    }
    mock_consume.return_value = "nonce"
    mock_get_user.return_value = MagicMock(tokens_valid_after_timestamp=None)
    from lanonna_api.domain.errors import ForbiddenError

    with pytest.raises(ForbiddenError):
        complete_biometric_sign_in("c", "ch", "AAAA")


@patch("lanonna_api.domain.biometric_sign_in.revoke_credential")
@patch("lanonna_api.domain.biometric_sign_in.firebase_auth.get_user")
@patch("lanonna_api.domain.biometric_sign_in.get_active_credential")
def test_complete_sign_in_deleted_user(mock_get, mock_get_user, mock_revoke):
    mock_get.return_value = {
        "firebase_uid": "uid",
        "revoked_at": None,
        "deleted_at": datetime.now(timezone.utc),
    }
    with pytest.raises(GoneError) as exc:
        complete_biometric_sign_in("c", "ch", "sig")
    assert exc.value.code == ErrorCode.USER_DELETED
