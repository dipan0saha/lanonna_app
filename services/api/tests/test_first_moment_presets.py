from datetime import date, datetime, timezone

from lanonna_api.first_moment_presets import (
    event_date_for_born_preset,
    event_date_for_expecting_preset,
    event_starts_at,
    event_starts_at_born,
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


def test_born_preset_clamps_to_today_when_birth_was_long_ago():
    birth = date(2026, 5, 1)
    today = date(2026, 10, 23)

    for offset in (0, 7, 14):
        assert event_date_for_born_preset(birth, offset, today=today) == today

    assert event_starts_at_born(birth, 14, today=today) == datetime(
        2026, 10, 23, 12, 0, tzinfo=timezone.utc
    )


def test_expecting_preset_between_one_and_two_weeks_out_clamps_only_gender_reveal():
    today = date(2026, 10, 23)
    due = date(2026, 11, 2)  # 10 days away

    assert event_date_for_expecting_preset(due, -14, today=today) == today
    assert event_date_for_expecting_preset(due, -7, today=today) == date(2026, 10, 26)
    assert event_date_for_expecting_preset(due, 0, today=today) == due


def test_expecting_preset_with_past_due_date_lands_today():
    today = date(2026, 10, 23)
    due = date(2026, 10, 20)

    for offset in (-14, -7, 0):
        assert event_date_for_expecting_preset(due, offset, today=today) == today


def test_expecting_preset_offsets_are_minus_14_minus_7_and_0():
    from lanonna_api.first_moment_presets import EXPECTING_EVENTS

    assert [(p.id, p.day_offset) for p in EXPECTING_EVENTS] == [
        ("gender_reveal", -14),
        ("baby_shower", -7),
        ("due_date", 0),
    ]
