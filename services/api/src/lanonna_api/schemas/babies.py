from __future__ import annotations

import uuid
from datetime import date
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

from lanonna_api.schemas.first_moment import NameSuggestionRow


class BabyCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    gender: Literal["male", "female", "unknown"] | None = None
    expected_birth_date: date | None = None
    actual_birth_date: date | None = None
    lifecycle_status: Literal["expecting", "born"] = "expecting"
    relationship_label: str | None = Field(default=None, max_length=80)
    profile_name_suggestions: list[NameSuggestionRow] = Field(
        default_factory=list,
        max_length=5,
    )

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Baby name is required.")
        return trimmed


class BabyUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    gender: Literal["male", "female", "unknown"] | None = None
    expected_birth_date: date | None = None
    actual_birth_date: date | None = None
    lifecycle_status: Literal["expecting", "born"] | None = None
    avatar_url: str | None = Field(default=None, max_length=2048)
    profile_name_suggestions: list[NameSuggestionRow] | None = Field(
        default=None,
        max_length=5,
    )


class BabySummary(BaseModel):
    id: uuid.UUID
    name: str
    gender: str | None
    expected_birth_date: date | None
    actual_birth_date: date | None
    lifecycle_status: str
    role: Literal["owner", "follower"]
    relationship_label: str | None
    avatar_url: str | None = None
    can_leave: bool = True
    names_closed: bool = False
    predictions_closed: bool = False
