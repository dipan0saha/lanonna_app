from __future__ import annotations

import uuid
from datetime import date
from typing import Annotated, Any, Literal

from pydantic import AfterValidator, BaseModel, Field

from lanonna_api.input_limits import MAX_BABY_NAME_LEN
from lanonna_api.schemas.first_moment import NameSuggestionRow


BabyGenderValue = Literal["male", "female", "unknown"]


def normalize_baby_name(value: str | None) -> str | None:
    """Trim the owner-entered name; blank means the baby has no name yet.

    An unnamed baby is stored as ``NULL``. The server never substitutes a
    placeholder ("Baby"); the app shows its localized fallback (FR-ONB-004).
    """
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed or None


BabyName = Annotated[
    str | None,
    Field(max_length=MAX_BABY_NAME_LEN),
    AfterValidator(normalize_baby_name),
]


class BabyCreateRequest(BaseModel):
    name: BabyName = None
    gender: BabyGenderValue = "unknown"
    expected_birth_date: date | None = None
    actual_birth_date: date | None = None
    lifecycle_status: Literal["expecting", "born"] = "expecting"
    relationship_label: str | None = Field(default=None, max_length=80)
    profile_name_suggestions: list[NameSuggestionRow] = Field(
        default_factory=list,
        max_length=5,
    )


class BabyUpdateRequest(BaseModel):
    """Partial update. ``name`` is written whenever the client sends it, so an
    explicit ``null`` (or blank) clears it; other ``null`` fields mean unchanged."""

    name: BabyName = None
    gender: BabyGenderValue | None = None
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
    name: str | None
    gender: BabyGenderValue
    expected_birth_date: date | None
    actual_birth_date: date | None
    lifecycle_status: str
    role: Literal["owner", "follower"]
    relationship_label: str | None
    avatar_url: str | None = None
    can_leave: bool = True
    names_closed: bool = False
    predictions_closed: bool = False
