"""Biometric challenge-response sign-in (domain, mocked SQL and Firebase)."""

from __future__ import annotations

import base64
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa

from lanonna_api.domain.biometric_sign_in import (
    BiometricKeyAlgorithm,
    complete_biometric_sign_in,
    enroll_biometric_credential,
    issue_biometric_challenge,
    verify_signature,
)
from lanonna_api.domain.errors import (
    ErrorCode,
    GoneError,
    InvalidInputError,
    UnauthenticatedError,
)

_MOD = "lanonna_api.domain.biometric_sign_in"
_CRED = uuid.uuid4()
_CHALLENGE = uuid.uuid4()


def _pem(public_key) -> str:
    return public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()


def _ec_keypair():
    private_key = ec.generate_private_key(ec.SECP256R1())
    return private_key, _pem(private_key.public_key())


def _sign(private_key, payload: str) -> str:
    # Same as the plugin: DER ECDSA over the UTF-8 payload, standard Base64.
    der = private_key.sign(payload.encode(), ec.ECDSA(hashes.SHA256()))
    return base64.b64encode(der).decode()


def _row(pub: str, *, created_at: datetime | None = None) -> dict:
    return {
        "id": _CRED,
        "firebase_uid": "uid-1",
        "public_key_pem": pub,
        "algorithm": BiometricKeyAlgorithm.ECDSA_P256_SHA256.value,
        "created_at": created_at or datetime.now(timezone.utc) - timedelta(days=1),
    }


def _user(*, disabled: bool = False, valid_after_ms: int | None = None) -> MagicMock:
    return MagicMock(disabled=disabled, tokens_valid_after_timestamp=valid_after_ms)


@patch(f"{_MOD}.register_credential")
def test_enroll_accepts_p256_pem(mock_register):
    mock_register.return_value = {"id": "cred-1", "created_at": "t"}
    _, pub = _ec_keypair()
    out = enroll_biometric_credential(
        "uid", " device-1234567890ab ", pub, BiometricKeyAlgorithm.ECDSA_P256_SHA256
    )
    assert out["id"] == "cred-1"
    mock_register.assert_called_once_with(
        "uid", "device-1234567890ab", pub.strip(), "ecdsa_p256_sha256"
    )


@pytest.mark.parametrize(
    "pem",
    [
        "not a key",
        _pem(rsa.generate_private_key(public_exponent=65537, key_size=2048).public_key()),
        _pem(ec.generate_private_key(ec.SECP384R1()).public_key()),
    ],
)
@patch(f"{_MOD}.register_credential")
def test_enroll_rejects_non_p256_keys(mock_register, pem):
    with pytest.raises(InvalidInputError):
        enroll_biometric_credential(
            "uid", "device-1234567890ab", pem, BiometricKeyAlgorithm.ECDSA_P256_SHA256
        )
    mock_register.assert_not_called()


@patch(f"{_MOD}.create_challenge")
@patch(f"{_MOD}.get_live_credential")
def test_issue_challenge_for_live_credential(mock_get, mock_create):
    mock_get.return_value = {"id": _CRED}
    mock_create.return_value = {"challenge_id": "ch", "nonce": "n", "expires_at": "t"}
    assert issue_biometric_challenge(_CRED)["nonce"] == "n"


@patch(f"{_MOD}.create_challenge")
@patch(f"{_MOD}.get_live_credential", return_value=None)
def test_issue_challenge_rejects_unusable_credential(_mock_get, mock_create):
    with pytest.raises(UnauthenticatedError) as exc:
        issue_biometric_challenge(_CRED)
    assert exc.value.code == ErrorCode.BIOMETRIC_CREDENTIAL_INVALID
    mock_create.assert_not_called()


@patch(f"{_MOD}.firebase_auth.create_custom_token", return_value=b"tok")
@patch(f"{_MOD}.firebase_auth.get_user")
@patch(f"{_MOD}._ensure_firebase")
@patch(f"{_MOD}.mark_credential_used")
@patch(f"{_MOD}.get_live_credential")
@patch(f"{_MOD}.consume_challenge")
def test_sign_in_success(mock_consume, mock_get, mock_mark, _fb, mock_user, mock_token):
    private_key, pub = _ec_keypair()
    mock_consume.return_value = "nonce-abc"
    mock_get.return_value = _row(pub)
    mock_user.return_value = _user()
    out = complete_biometric_sign_in(_CRED, _CHALLENGE, _sign(private_key, "nonce-abc"))
    assert out == {"custom_token": "tok"}
    mock_consume.assert_called_once_with(_CHALLENGE, _CRED)
    mock_mark.assert_called_once_with(_CRED)
    mock_token.assert_called_once_with("uid-1")


@patch(f"{_MOD}.get_live_credential")
@patch(f"{_MOD}.consume_challenge", return_value=None)
def test_sign_in_expired_or_used_challenge(_consume, mock_get):
    with pytest.raises(GoneError) as exc:
        complete_biometric_sign_in(_CRED, _CHALLENGE, "AAAAAAAA")
    assert exc.value.code == ErrorCode.BIOMETRIC_CHALLENGE_EXPIRED
    mock_get.assert_not_called()


@patch(f"{_MOD}.firebase_auth.create_custom_token")
@patch(f"{_MOD}.get_live_credential", return_value=None)
@patch(f"{_MOD}.consume_challenge", return_value="nonce")
def test_sign_in_revoked_or_deleted_credential(_consume, _get, mock_token):
    with pytest.raises(UnauthenticatedError) as exc:
        complete_biometric_sign_in(_CRED, _CHALLENGE, "AAAAAAAA")
    assert exc.value.code == ErrorCode.BIOMETRIC_CREDENTIAL_INVALID
    mock_token.assert_not_called()


@patch(f"{_MOD}.firebase_auth.create_custom_token")
@patch(f"{_MOD}.firebase_auth.get_user")
@patch(f"{_MOD}.get_live_credential")
@patch(f"{_MOD}.consume_challenge", return_value="nonce")
def test_sign_in_bad_signature(_consume, mock_get, mock_user, mock_token):
    other_key, _ = _ec_keypair()
    _, pub = _ec_keypair()
    mock_get.return_value = _row(pub)
    with pytest.raises(UnauthenticatedError) as exc:
        complete_biometric_sign_in(_CRED, _CHALLENGE, _sign(other_key, "nonce"))
    assert exc.value.code == ErrorCode.BIOMETRIC_CREDENTIAL_INVALID
    mock_user.assert_not_called()
    mock_token.assert_not_called()


@pytest.mark.parametrize(
    "user_state",
    [
        "missing",
        "disabled",
        "sessions_revoked",
    ],
)
@patch(f"{_MOD}.firebase_auth.create_custom_token")
@patch(f"{_MOD}.revoke_credential")
@patch(f"{_MOD}.firebase_auth.get_user")
@patch(f"{_MOD}._ensure_firebase")
@patch(f"{_MOD}.get_live_credential")
@patch(f"{_MOD}.consume_challenge", return_value="nonce")
def test_sign_in_rejects_and_revokes_on_account_state(
    _consume, mock_get, _fb, mock_user, mock_revoke, mock_token, user_state
):
    from firebase_admin import auth as firebase_auth

    private_key, pub = _ec_keypair()
    enrolled = datetime.now(timezone.utc) - timedelta(days=1)
    mock_get.return_value = _row(pub, created_at=enrolled)
    if user_state == "missing":
        mock_user.side_effect = firebase_auth.UserNotFoundError("gone")
    elif user_state == "disabled":
        mock_user.return_value = _user(disabled=True)
    else:
        mock_user.return_value = _user(
            valid_after_ms=int((enrolled + timedelta(hours=1)).timestamp() * 1000)
        )
    with pytest.raises(UnauthenticatedError) as exc:
        complete_biometric_sign_in(_CRED, _CHALLENGE, _sign(private_key, "nonce"))
    assert exc.value.code == ErrorCode.BIOMETRIC_CREDENTIAL_INVALID
    mock_revoke.assert_called_once_with(_CRED)
    mock_token.assert_not_called()


@patch(f"{_MOD}.firebase_auth.create_custom_token", return_value=b"tok")
@patch(f"{_MOD}.mark_credential_used")
@patch(f"{_MOD}.firebase_auth.get_user")
@patch(f"{_MOD}._ensure_firebase")
@patch(f"{_MOD}.get_live_credential")
@patch(f"{_MOD}.consume_challenge", return_value="nonce")
def test_sessions_revoked_before_enrollment_still_signs_in(
    _consume, mock_get, _fb, mock_user, _mark, _token
):
    private_key, pub = _ec_keypair()
    enrolled = datetime.now(timezone.utc) - timedelta(hours=1)
    mock_get.return_value = _row(pub, created_at=enrolled)
    mock_user.return_value = _user(
        valid_after_ms=int((enrolled - timedelta(days=3)).timestamp() * 1000)
    )
    assert complete_biometric_sign_in(_CRED, _CHALLENGE, _sign(private_key, "nonce"))


def test_verify_signature_rejects_malformed_input():
    private_key, pub = _ec_keypair()
    good = _sign(private_key, "n")
    assert verify_signature(pub, "n", good)
    assert not verify_signature(pub, "other", good)
    assert not verify_signature(pub, "n", "!!not-base64!!")
    assert not verify_signature(pub, "n", base64.b64encode(b"\x00" * 64).decode())
