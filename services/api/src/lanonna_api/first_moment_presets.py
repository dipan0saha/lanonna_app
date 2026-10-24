from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone

from lanonna_api.domain.date_validation import utc_today


@dataclass(frozen=True)
class EventPreset:
    id: str
    label: str
    day_offset: int


@dataclass(frozen=True)
class RegistryPreset:
    id: str
    label: str
    # Catalog row this seed stands for (registry_suggestions.json), so registry
    # AI stops offering it; None for presets with no catalog row (#412).
    catalog_suggestion_id: str | None


EXPECTING_EVENTS: tuple[EventPreset, ...] = (
    EventPreset("gender_reveal", "Gender reveal", -14),
    EventPreset("baby_shower", "Baby shower", -7),
    EventPreset("due_date", "Due Date", 0),
)

EXPECTING_REGISTRY: tuple[RegistryPreset, ...] = (
    RegistryPreset(
        "swaddle_blankets",
        "Swaddle Blankets (set of 3)",
        "swaddle_blankets",
    ),
    RegistryPreset("crib_mattress", "Crib & Mattress", "crib_mattress"),
    RegistryPreset("diaper_stockpile", "Diapers (newborn)", "diaper_stockpile"),
)

BORN_EVENTS: tuple[EventPreset, ...] = (
    EventPreset("first_pediatric_visit", "First pediatric visit", 0),
    EventPreset("baptism", "Baptism", 7),
    EventPreset("first_holidays", "First Holidays", 14),
)

BORN_REGISTRY: tuple[RegistryPreset, ...] = (
    RegistryPreset("diaper_stockpile", "Diapers (newborn)", "diaper_stockpile"),
    RegistryPreset("onesies", "Onesies", None),
    RegistryPreset("bottles", "Bottles", None),
)

_EVENT_MAP: dict[str, EventPreset] = {
    p.id: p for p in (*EXPECTING_EVENTS, *BORN_EVENTS)
}
_REGISTRY_MAP: dict[str, RegistryPreset] = {
    p.id: p for p in (*EXPECTING_REGISTRY, *BORN_REGISTRY)
}


def anchor_midday_utc(anchor_date) -> datetime:
    return datetime(
        anchor_date.year,
        anchor_date.month,
        anchor_date.day,
        12,
        0,
        0,
        tzinfo=timezone.utc,
    )


def event_starts_at(anchor_date, day_offset: int) -> datetime:
    return anchor_midday_utc(anchor_date) + timedelta(days=day_offset)


def event_date_for_expecting_preset(
    due_date: date,
    day_offset: int,
    *,
    today: date | None = None,
) -> date:
    """Calendar date for an expecting first-moment preset, never before [today]."""
    reference = today if today is not None else utc_today()
    computed = due_date + timedelta(days=day_offset)
    return computed if computed >= reference else reference


def event_starts_at_expecting(
    due_date: date,
    day_offset: int,
    *,
    today: date | None = None,
) -> datetime:
    return anchor_midday_utc(
        event_date_for_expecting_preset(due_date, day_offset, today=today)
    )


def event_date_for_born_preset(
    birth_date: date,
    day_offset: int,
    *,
    today: date | None = None,
) -> date:
    """Calendar date for a born first-moment preset, never before [today] (#412)."""
    reference = today if today is not None else utc_today()
    computed = birth_date + timedelta(days=day_offset)
    return computed if computed >= reference else reference


def event_starts_at_born(
    birth_date: date,
    day_offset: int,
    *,
    today: date | None = None,
) -> datetime:
    return anchor_midday_utc(
        event_date_for_born_preset(birth_date, day_offset, today=today)
    )


def event_preset(preset_id: str) -> EventPreset | None:
    return _EVENT_MAP.get(preset_id)


def registry_preset(preset_id: str) -> RegistryPreset | None:
    return _REGISTRY_MAP.get(preset_id)
