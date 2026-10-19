from __future__ import annotations

from fastapi import APIRouter, Depends, status

from lanonna_api.app_check import require_app_check
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.biometric_sign_in import (
    complete_biometric_sign_in,
    enroll_biometric_credential,
    issue_biometric_challenge,
    revoke_credential,
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

router = APIRouter(prefix="/v1", tags=["biometric-auth"])
_public_deps = [Depends(require_app_check)]


@router.post(
    "/me/biometric-credentials",
    response_model=BiometricCredentialEnrollResponse,
    dependencies=_public_deps,
)
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


@router.delete(
    "/me/biometric-credentials/{credential_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=_public_deps,
)
def revoke_biometric_credential_route(
    credential_id: str,
    user: AppUser = Depends(current_app_user),
) -> None:
    revoke_credential(user.uid, credential_id)


@router.post(
    "/auth/biometric/challenge",
    response_model=BiometricChallengeResponse,
    dependencies=_public_deps,
)
def biometric_challenge_route(
    body: BiometricChallengeRequest,
) -> BiometricChallengeResponse:
    try:
        result = issue_biometric_challenge(body.credential_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return BiometricChallengeResponse(**result)


@router.post(
    "/auth/biometric/sign-in",
    response_model=BiometricSignInResponse,
    dependencies=_public_deps,
)
def biometric_sign_in_route(
    body: BiometricSignInRequest,
) -> BiometricSignInResponse:
    try:
        result = complete_biometric_sign_in(
            body.credential_id,
            body.challenge_id,
            body.signature,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return BiometricSignInResponse(**result)
