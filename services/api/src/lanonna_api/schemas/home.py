from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel


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


class ActivityEventItem(BaseModel):
    id: uuid.UUID
    event_type: str
    summary: str
    created_at: str
    actor_display_name: str | None = None
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
    favorite_photos: list[dict[str, Any]] = []
    registry_open_count: int = 0
    registry_highlights: list[dict[str, Any]] = []
    recent_registry_purchases: list[dict[str, Any]] = []
    upcoming_events: list[dict[str, Any]] = []
    rsvp_reminders: list[dict[str, Any]] = []
    notification_preview: list[dict[str, Any]] = []


class HomeSummaryResponse(BaseModel):
    baby_profile_id: uuid.UUID
    lifecycle_status: str
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
