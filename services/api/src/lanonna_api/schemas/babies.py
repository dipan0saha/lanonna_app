from __future__ import annotations

import uuid
from datetime import date
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class BabyCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    gender: Literal["male", "female", "unknown"] | None = None
    expected_birth_date: date | None = None
    actual_birth_date: date | None = None
    lifecycle_status: Literal["expecting", "born"] = "expecting"

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


def baby_summary_from_row(row: dict[str, Any]) -> BabySummary:
    return BabySummary(
        id=row["id"],
        name=row["name"],
        gender=row.get("gender"),
        expected_birth_date=row.get("expected_birth_date"),
        actual_birth_date=row.get("actual_birth_date"),
        lifecycle_status=row.get("lifecycle_status") or "expecting",
        role=row["role"],
        relationship_label=row.get("relationship_label"),
        avatar_url=row.get("avatar_url"),
    )
