"""Biometric sign-in after logout (design: docs/engineering/rca/biometric-signin-after-logout.md)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from lanonna_api.app_check import require_app_check
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.biometric_sign_in import (
    complete_biometric_sign_in,
    enroll_biometric_credential,
    issue_biometric_challenge,
)
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.schemas.biometric_auth import (
    BiometricChallengeRequest,
    BiometricChallengeResponse,
    BiometricCredentialEnrollRequest,
    BiometricCredentialEnrollResponse,
    BiometricSignInRequest,
    BiometricSignInResponse,
)

# Every route needs App Check; the two /auth routes are the only API routes
# without a Firebase ID token, so they are also rate limited (rate_limit.py).
router = APIRouter(prefix="/v1", tags=["biometric-auth"], dependencies=[Depends(require_app_check)])


@router.post("/me/biometric-credentials", response_model=BiometricCredentialEnrollResponse)
def enroll_biometric_credential_route(
    body: BiometricCredentialEnrollRequest,
    user: AppUser = Depends(current_app_user),
) -> BiometricCredentialEnrollResponse:
    try:
        result = enroll_biometric_credential(
            user.uid,
            body.device_id,
            body.public_key_pem,
            body.algorithm,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return BiometricCredentialEnrollResponse(**result)


@router.post("/auth/biometric/challenge", response_model=BiometricChallengeResponse)
def biometric_challenge_route(body: BiometricChallengeRequest) -> BiometricChallengeResponse:
    try:
        result = issue_biometric_challenge(body.credential_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return BiometricChallengeResponse(**result)


@router.post("/auth/biometric/sign-in", response_model=BiometricSignInResponse)
def biometric_sign_in_route(body: BiometricSignInRequest) -> BiometricSignInResponse:
    try:
        result = complete_biometric_sign_in(
            body.credential_id,
            body.challenge_id,
            body.signature,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return BiometricSignInResponse(**result)
