from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.first_moment_presets import (
    event_preset,
    event_starts_at,
    registry_preset,
)
from lanonna_api.repositories.babies import get_baby_for_owner


def _anchor_date(baby: dict[str, Any]) -> date:
    lifecycle = baby.get("lifecycle_status") or "expecting"
    if lifecycle == "born":
        actual = baby.get("actual_birth_date")
        if actual is not None:
            return actual
    expected = baby.get("expected_birth_date")
    if expected is not None:
        return expected
    return date.today() + timedelta(days=90)


def seed_first_moment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_preset_ids: list[str],
    registry_preset_ids: list[str],
    name_suggestions: list[dict[str, str]],
) -> dict[str, int]:
    baby = get_baby_for_owner(firebase_uid, baby_profile_id)
    if baby is None:
        raise PermissionError("Owner access required")

    anchor = _anchor_date(baby)
    events_created = 0
    registry_created = 0
    names_created = 0

    with get_connection() as conn:
        for preset_id in event_preset_ids:
            preset = event_preset(preset_id)
            if preset is None:
                continue
            starts = event_starts_at(anchor, preset.day_offset)
            conn.execute(
                """
                INSERT INTO events (
                    baby_profile_id, created_by_firebase_uid,
                    title, starts_at
                )
                VALUES (%s, %s, %s, %s)
                """,
                (baby_profile_id, firebase_uid, preset.label, starts),
            )
            events_created += 1

        for preset_id in registry_preset_ids:
            preset = registry_preset(preset_id)
            if preset is None:
                continue
            conn.execute(
                """
                INSERT INTO registry_items (
                    baby_profile_id, created_by_firebase_uid, name, priority
                )
                VALUES (%s, %s, %s, 3)
                """,
                (baby_profile_id, firebase_uid, preset.label),
            )
            registry_created += 1

        for row in name_suggestions:
            name = (row.get("name") or "").strip()
            if not name:
                continue
            gender = row.get("gender") or "unknown"
            if gender not in ("male", "female", "unknown"):
                gender = "unknown"
            conn.execute(
                """
                INSERT INTO name_suggestions (
                    baby_profile_id, suggested_by_firebase_uid,
                    suggested_name, gender
                )
                VALUES (%s, %s, %s, %s)
                """,
                (baby_profile_id, firebase_uid, name, gender),
            )
            names_created += 1

    return {
        "events_created": events_created,
        "registry_items_created": registry_created,
        "name_suggestions_created": names_created,
    }
