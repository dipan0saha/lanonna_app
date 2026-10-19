from __future__ import annotations

import base64
import binascii
import logging
from datetime import datetime, timezone
from typing import Any

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from firebase_admin import auth as firebase_auth

from lanonna_api.auth import _ensure_firebase
from lanonna_api.domain.errors import ErrorCode, ForbiddenError, GoneError, InvalidInputError
from lanonna_api.repositories.biometric_credentials import (
    consume_challenge,
    create_challenge,
    get_active_credential,
    mark_credential_used,
    register_credential,
    revoke_all_for_user,
    revoke_credential,
)

logger = logging.getLogger("lanonna.biometric_sign_in")

_ALLOWED_ALGORITHMS = frozenset({"ECDSA_SHA256", "RSA_SHA256"})


def enroll_biometric_credential(
    firebase_uid: str,
    device_id: str,
    public_key_pem: str,
    algorithm: str,
) -> dict[str, Any]:
    algorithm = algorithm.upper()
    if algorithm not in _ALLOWED_ALGORITHMS:
        raise InvalidInputError(
            ErrorCode.INVALID_REQUEST,
            "Unsupported biometric signature algorithm.",
        )
    try:
        _load_public_key(public_key_pem)
    except ValueError as exc:
        raise InvalidInputError(
            ErrorCode.INVALID_REQUEST,
            "Invalid public key.",
        ) from exc
    return register_credential(firebase_uid, device_id, public_key_pem, algorithm)


def issue_biometric_challenge(credential_id: str) -> dict[str, Any]:
    row = get_active_credential(credential_id)
    if row is None or row.get("revoked_at") is not None:
        raise GoneError(ErrorCode.REVOKED, "Biometric credential not found or revoked.")
    if row.get("deleted_at") is not None:
        raise GoneError(ErrorCode.USER_DELETED, "Account no longer exists.")
    return create_challenge(credential_id)


def complete_biometric_sign_in(
    credential_id: str,
    challenge_id: str,
    signature_b64: str,
) -> dict[str, str]:
    row = get_active_credential(credential_id)
    if row is None or row.get("revoked_at") is not None:
        logger.info(
            "biometric_sign_in_rejected credential=%s reason=revoked_or_missing",
            credential_id,
        )
        raise GoneError(ErrorCode.REVOKED, "Biometric credential not found or revoked.")
    if row.get("deleted_at") is not None:
        raise GoneError(ErrorCode.USER_DELETED, "Account no longer exists.")

    firebase_uid = row["firebase_uid"]
    _ensure_firebase()
    try:
        user_record = firebase_auth.get_user(firebase_uid)
    except firebase_auth.UserNotFoundError:
        raise GoneError(ErrorCode.USER_DELETED, "Account no longer exists.") from None

    tokens_valid_after = user_record.tokens_valid_after_timestamp
    if tokens_valid_after:
        created_at: datetime = row["created_at"]
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        if created_at.timestamp() < tokens_valid_after / 1000.0:
            revoke_credential(firebase_uid, credential_id)
            raise ForbiddenError(
                ErrorCode.REVOKED,
                "Biometric credential expired after password change.",
            )

    nonce = consume_challenge(challenge_id, credential_id)
    if nonce is None:
        raise GoneError(ErrorCode.EXPIRED, "Challenge expired or already used.")

    if not _verify_signature(
        row["public_key_pem"],
        row["algorithm"],
        nonce,
        signature_b64,
    ):
        logger.info(
            "biometric_sign_in_rejected credential=%s reason=bad_signature uid=%s",
            credential_id,
            firebase_uid,
        )
        raise ForbiddenError(
            ErrorCode.INVALID_REQUEST,
            "Biometric signature verification failed.",
        )

    mark_credential_used(credential_id)
    custom_token = firebase_auth.create_custom_token(firebase_uid).decode("utf-8")
    logger.info(
        "biometric_sign_in_success credential=%s uid=%s",
        credential_id,
        firebase_uid,
    )
    return {"custom_token": custom_token, "firebase_uid": firebase_uid}


def revoke_user_biometric_credentials(firebase_uid: str) -> int:
    return revoke_all_for_user(firebase_uid)


def _load_public_key(public_key_pem: str):
    return serialization.load_pem_public_key(public_key_pem.encode("utf-8"))


def _verify_signature(
    public_key_pem: str,
    algorithm: str,
    payload: str,
    signature_b64: str,
) -> bool:
    public_key = _load_public_key(public_key_pem)
    try:
        signature = base64.b64decode(signature_b64, validate=True)
    except (ValueError, binascii.Error):
        return False

    data = payload.encode("utf-8")
    try:
        if algorithm == "ECDSA_SHA256":
            if not isinstance(public_key, ec.EllipticCurvePublicKey):
                return False
            public_key.verify(signature, data, ec.ECDSA(hashes.SHA256()))
            return True
        if algorithm == "RSA_SHA256":
            if not isinstance(public_key, rsa.RSAPublicKey):
                return False
            public_key.verify(
                signature,
                data,
                padding.PKCS1v15(),
                hashes.SHA256(),
            )
            return True
    except InvalidSignature:
        return False
    return False
