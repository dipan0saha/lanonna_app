from pydantic import BaseModel, Field


class BiometricCredentialEnrollRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    public_key_pem: str = Field(min_length=32, max_length=8192)
    algorithm: str = Field(min_length=3, max_length=32)


class BiometricCredentialEnrollResponse(BaseModel):
    id: str
    created_at: str


class BiometricChallengeRequest(BaseModel):
    credential_id: str = Field(min_length=36, max_length=36)


class BiometricChallengeResponse(BaseModel):
    challenge_id: str
    nonce: str
    expires_at: str


class BiometricSignInRequest(BaseModel):
    credential_id: str = Field(min_length=36, max_length=36)
    challenge_id: str = Field(min_length=36, max_length=36)
    signature: str = Field(min_length=16, max_length=4096)


class BiometricSignInResponse(BaseModel):
    custom_token: str
    firebase_uid: str
