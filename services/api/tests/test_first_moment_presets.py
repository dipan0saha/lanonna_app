from datetime import date, datetime, timezone

from lanonna_api.first_moment_presets import (
    event_date_for_expecting_preset,
    event_starts_at,
    event_starts_at_expecting,
)


def test_expecting_preset_offsets_from_due_date():
    due = date(2027, 1, 20)
    today = date(2026, 10, 23)

    assert event_date_for_expecting_preset(due, -14, today=today) == date(2027, 1, 6)
    assert event_date_for_expecting_preset(due, -7, today=today) == date(2027, 1, 13)
    assert event_date_for_expecting_preset(due, 0, today=today) == due

    gender = event_starts_at_expecting(due, -14, today=today)
    shower = event_starts_at_expecting(due, -7, today=today)
    due_day = event_starts_at_expecting(due, 0, today=today)

    assert gender == datetime(2027, 1, 6, 12, 0, tzinfo=timezone.utc)
    assert shower == datetime(2027, 1, 13, 12, 0, tzinfo=timezone.utc)
    assert due_day == datetime(2027, 1, 20, 12, 0, tzinfo=timezone.utc)


def test_expecting_preset_clamps_to_today_when_due_date_is_soon():
    due = date(2026, 10, 28)
    today = date(2026, 10, 23)

    assert event_date_for_expecting_preset(due, -14, today=today) == today
    assert event_date_for_expecting_preset(due, -7, today=today) == today
    assert event_date_for_expecting_preset(due, 0, today=today) == due

    assert event_starts_at_expecting(due, 0, today=today) == datetime(
        2026, 10, 28, 12, 0, tzinfo=timezone.utc
    )


def test_born_preset_still_counts_forward_from_birth_date():
    birth = date(2026, 5, 1)
    assert event_starts_at(birth, 0) == datetime(2026, 5, 1, 12, 0, tzinfo=timezone.utc)
    assert event_starts_at(birth, 7) == datetime(2026, 5, 8, 12, 0, tzinfo=timezone.utc)
