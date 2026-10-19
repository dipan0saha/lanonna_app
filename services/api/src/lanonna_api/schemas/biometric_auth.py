import uuid

from pydantic import BaseModel, Field

from lanonna_api.domain.biometric_sign_in import BiometricKeyAlgorithm


class BiometricCredentialEnrollRequest(BaseModel):
    device_id: str = Field(min_length=16, max_length=128)
    public_key_pem: str = Field(min_length=32, max_length=4096)
    algorithm: BiometricKeyAlgorithm


class BiometricCredentialEnrollResponse(BaseModel):
    id: str
    created_at: str


class BiometricChallengeRequest(BaseModel):
    credential_id: uuid.UUID


class BiometricChallengeResponse(BaseModel):
    challenge_id: str
    nonce: str
    expires_at: str


class BiometricSignInRequest(BaseModel):
    credential_id: uuid.UUID
    challenge_id: uuid.UUID
    # A DER P-256 signature is at most 72 bytes (96 Base64 characters).
    signature: str = Field(min_length=8, max_length=256)


class BiometricSignInResponse(BaseModel):
    custom_token: str
