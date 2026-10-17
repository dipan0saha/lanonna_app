from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class GenderTotals(BaseModel):
    male: int = 0
    female: int = 0


class TopNameInsight(BaseModel):
    suggested_name: str
    like_count: int


class FamilyInsightSummary(BaseModel):
    name_suggestion_count: int
    vote_count: int
    gender_totals: GenderTotals | None = None
    top_name: TopNameInsight | None = None
    top_birthdate_guess: str | None = None
    show_rich_insight: bool = False


class ActivityEventItem(BaseModel):
    """Structured feed row; the app renders the sentence from ``event_type`` + ``params``."""

    id: uuid.UUID
    event_type: str
    params: dict[str, str] = Field(default_factory=dict)
    # English diagnostic copy; shown only by an app that does not know the type.
    summary: str
    created_at: str
    # Current display names; null when the person has none (app shows its fallback).
    actor_display_name: str | None = None
    target_display_name: str | None = None
    photo_id: uuid.UUID | None = None


class NextUpEvent(BaseModel):
    id: uuid.UUID
    title: str
    starts_at: datetime
    location: str | None = None


class GettingStartedTask(BaseModel):
    id: str
    label: str
    done: bool
    deep_link: str | None = None


class GettingStartedSummary(BaseModel):
    completed_count: int
    total: int
    tasks: list[GettingStartedTask]


class HomeTeasersResponse(BaseModel):
    recent_photos: list[dict[str, Any]] = []
    upcoming_events: list[dict[str, Any]] = []


class HomeSummaryResponse(BaseModel):
    baby_profile_id: uuid.UUID
    lifecycle_status: str
    names_closed: bool = False
    predictions_closed: bool = False
    days_to_due: int | None
    birth_welcome: dict[str, Any] | None = None
    family_insight: FamilyInsightSummary
    recent_activity: list[ActivityEventItem]
    next_up_event: NextUpEvent | None = None
    getting_started: GettingStartedSummary | None = None
    system_announcements: list[dict[str, Any]] = []
    new_followers: list[dict[str, Any]] | None = None
    invite_status: list[dict[str, Any]] | None = None
    teasers: HomeTeasersResponse | None = None
