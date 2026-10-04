from datetime import date, datetime

from pydantic import BaseModel, Field, field_validator


class ProfileResponse(BaseModel):
    firebase_uid: str
    email: str | None
    display_name: str | None
    avatar_url: str | None = None
    phone: str | None = None
    birth_date: date | None = None
    country_code: str | None = None
    postal_code: str | None = None
    terms_accepted_at: datetime | None = None
    owner_onboarding_completed: bool
    created_at: str
    updated_at: str


class ProfileUpdateRequest(BaseModel):
    display_name: str = Field(min_length=1, max_length=100)
    avatar_url: str | None = Field(default=None, max_length=2048)
    phone: str | None = Field(default=None, max_length=40)
    birth_date: date | None = None
    country_code: str | None = Field(default=None, min_length=2, max_length=2)
    postal_code: str | None = Field(default=None, max_length=32)
    accept_terms: bool | None = None

    @field_validator("country_code")
    @classmethod
    def normalize_country(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        return value.strip().upper()

    @field_validator("phone", "postal_code")
    @classmethod
    def strip_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        return trimmed if trimmed else None
