from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class NameSuggestionRow(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    gender: Literal["male", "female", "unknown"] = "unknown"


class FirstMomentSeedRequest(BaseModel):
    event_preset_ids: list[str] = Field(default_factory=list, max_length=20)
    registry_preset_ids: list[str] = Field(default_factory=list, max_length=20)
    name_suggestions: list[NameSuggestionRow] = Field(default_factory=list, max_length=20)


class FirstMomentSeedResponse(BaseModel):
    events_created: int
    registry_items_created: int
    name_suggestions_created: int
