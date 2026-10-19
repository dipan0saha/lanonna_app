"""Biometric sign-in after logout: device-bound key, server nonce, custom token.

Enrollment (signed in) stores the public half of a hardware-backed P-256 key
created by the app's ``biometric_signature`` plugin. Sign-in is two
unauthenticated, App Check-gated calls: a single-use nonce for a credential,
then the device's signature over that nonce's UTF-8 bytes. The plugin signs with
``SHA256withECDSA`` (Android Keystore) / ``ecdsaSignatureMessageX962SHA256``
(Secure Enclave): an ASN.1 DER signature, sent as standard Base64. A valid
signature from a live credential of a live account yields a Firebase custom
token for that account.
"""

from __future__ import annotations

import base64
import binascii
import logging
import uuid
from enum import StrEnum
from typing import Any

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from firebase_admin import auth as firebase_auth

from lanonna_api.auth import _ensure_firebase
from lanonna_api.domain.errors import (
    ErrorCode,
    GoneError,
    InvalidInputError,
    UnauthenticatedError,
)
from lanonna_api.repositories.biometric_credentials import (
    consume_challenge,
    create_challenge,
    get_live_credential,
    mark_credential_used,
    register_credential,
    revoke_all_for_user,
    revoke_credential,
)

logger = logging.getLogger("lanonna.biometric_sign_in")


class BiometricKeyAlgorithm(StrEnum):
    ECDSA_P256_SHA256 = "ecdsa_p256_sha256"


def _credential_invalid() -> UnauthenticatedError:
    return UnauthenticatedError(
        ErrorCode.BIOMETRIC_CREDENTIAL_INVALID,
        "Biometric credential cannot sign in.",
    )


def enroll_biometric_credential(
    firebase_uid: str,
    device_id: str,
    public_key_pem: str,
    algorithm: BiometricKeyAlgorithm,
) -> dict[str, Any]:
    try:
        key = serialization.load_pem_public_key(public_key_pem.encode("utf-8"))
    except (ValueError, TypeError) as exc:
        raise InvalidInputError(ErrorCode.INVALID_REQUEST, "Invalid public key.") from exc
    if not (
        isinstance(key, ec.EllipticCurvePublicKey)
        and isinstance(key.curve, ec.SECP256R1)
    ):
        raise InvalidInputError(
            ErrorCode.INVALID_REQUEST,
            "Biometric key must be EC P-256.",
        )
    return register_credential(
        firebase_uid,
        device_id.strip(),
        public_key_pem.strip(),
        BiometricKeyAlgorithm(algorithm).value,
    )


def issue_biometric_challenge(credential_id: uuid.UUID) -> dict[str, Any]:
    if get_live_credential(credential_id) is None:
        logger.info("biometric_challenge_rejected credential=%s", credential_id)
        raise _credential_invalid()
    return create_challenge(credential_id)


def complete_biometric_sign_in(
    credential_id: uuid.UUID,
    challenge_id: uuid.UUID,
    signature_b64: str,
) -> dict[str, str]:
    # Consume first: every attempt burns the nonce, pass or fail.
    nonce = consume_challenge(challenge_id, credential_id)
    if nonce is None:
        raise GoneError(
            ErrorCode.BIOMETRIC_CHALLENGE_EXPIRED,
            "Challenge expired or already used.",
        )
    row = get_live_credential(credential_id)
    if row is None:
        logger.info("biometric_sign_in_rejected credential=%s reason=not_live", credential_id)
        raise _credential_invalid()
    if not verify_signature(row["public_key_pem"], nonce, signature_b64):
        logger.info("biometric_sign_in_rejected credential=%s reason=bad_signature", credential_id)
        raise _credential_invalid()

    firebase_uid = row["firebase_uid"]
    _ensure_firebase()
    try:
        user_record = firebase_auth.get_user(firebase_uid)
    except firebase_auth.UserNotFoundError:
        user_record = None
    if user_record is None or user_record.disabled or _sessions_revoked_since(
        user_record, row
    ):
        # The account changed under this key (deleted, disabled, password reset or
        # sessions revoked): the key can never sign in again.
        revoke_credential(credential_id)
        logger.info(
            "biometric_sign_in_rejected credential=%s reason=account_state",
            credential_id,
        )
        raise _credential_invalid()

    mark_credential_used(credential_id)
    token = firebase_auth.create_custom_token(firebase_uid)
    logger.info("biometric_sign_in_success credential=%s", credential_id)
    return {"custom_token": token.decode("utf-8")}


def revoke_user_biometric_credentials(firebase_uid: str) -> int:
    return revoke_all_for_user(firebase_uid)


def _sessions_revoked_since(user_record: Any, row: dict[str, Any]) -> bool:
    """Firebase ``tokens_valid_after`` (ms) is later than the key's enrollment."""
    valid_after_ms = user_record.tokens_valid_after_timestamp
    if not valid_after_ms:
        return False
    return row["created_at"].timestamp() * 1000 < valid_after_ms


def verify_signature(public_key_pem: str, payload: str, signature_b64: str) -> bool:
    """ECDSA P-256 / SHA-256 DER signature over ``payload``'s UTF-8 bytes."""
    try:
        signature = base64.b64decode(signature_b64, validate=True)
        key = serialization.load_pem_public_key(public_key_pem.encode("utf-8"))
    except (ValueError, binascii.Error):
        return False
    if not isinstance(key, ec.EllipticCurvePublicKey):
        return False
    try:
        key.verify(signature, payload.encode("utf-8"), ec.ECDSA(hashes.SHA256()))
    except InvalidSignature:
        return False
    return True
