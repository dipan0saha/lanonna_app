from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


@dataclass(frozen=True)
class EventPreset:
    id: str
    label: str
    day_offset: int


@dataclass(frozen=True)
class RegistryPreset:
    id: str
    label: str


EXPECTING_EVENTS: tuple[EventPreset, ...] = (
    EventPreset("gender_reveal", "Gender Reveal", 0),
    EventPreset("baby_shower", "Baby Shower", 7),
    EventPreset("due_date", "Due Date", 14),
)

EXPECTING_REGISTRY: tuple[RegistryPreset, ...] = (
    RegistryPreset("swaddles", "Swaddles"),
    RegistryPreset("crib", "Crib"),
    RegistryPreset("diapers", "Diapers"),
)

BORN_EVENTS: tuple[EventPreset, ...] = (
    EventPreset("first_checkup", "First Checkup", 0),
    EventPreset("baptism", "Baptism", 7),
    EventPreset("first_holidays", "First Holidays", 14),
)

BORN_REGISTRY: tuple[RegistryPreset, ...] = (
    RegistryPreset("diapers", "Diapers"),
    RegistryPreset("onesies", "Onesies"),
    RegistryPreset("bottles", "Bottles"),
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


def event_preset(preset_id: str) -> EventPreset | None:
    return _EVENT_MAP.get(preset_id)


def registry_preset(preset_id: str) -> RegistryPreset | None:
    return _REGISTRY_MAP.get(preset_id)
