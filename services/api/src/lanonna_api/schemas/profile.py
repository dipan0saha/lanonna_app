from pydantic import BaseModel, Field


class ProfileResponse(BaseModel):
    firebase_uid: str
    email: str | None
    display_name: str | None
    avatar_url: str | None = None
    owner_onboarding_completed: bool
    created_at: str
    updated_at: str


class ProfileUpdateRequest(BaseModel):
    display_name: str = Field(min_length=1, max_length=100)
    avatar_url: str | None = Field(default=None, max_length=2048)
