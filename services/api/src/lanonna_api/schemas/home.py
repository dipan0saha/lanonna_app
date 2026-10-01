from __future__ import annotations

import uuid
from datetime import datetime

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


class HomeSummaryResponse(BaseModel):
    baby_profile_id: uuid.UUID
    lifecycle_status: str
    days_to_due: int | None
    family_insight: FamilyInsightSummary
    recent_activity: list[ActivityEventItem]
    next_up_event: NextUpEvent | None = None
    getting_started: GettingStartedSummary | None = None
