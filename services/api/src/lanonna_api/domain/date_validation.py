from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

# Allow calendar dates up to one day ahead of UTC for owners in timezones east of UTC.
BIRTH_DATE_UTC_SLACK_DAYS = 1

USER_BIRTH_DATE_MIN = date(1900, 1, 1)


def utc_today() -> date:
    return datetime.now(timezone.utc).date()


def validate_actual_birth_date(actual_birth_date: date) -> None:
    latest_allowed = utc_today() + timedelta(days=BIRTH_DATE_UTC_SLACK_DAYS)
    if actual_birth_date > latest_allowed:
        raise ValueError("Date of birth cannot be in the future.")


def validate_user_birth_date(birth_date: date) -> None:
    validate_actual_birth_date(birth_date)
    if birth_date < USER_BIRTH_DATE_MIN:
        raise ValueError("Enter a valid date of birth.")


def _as_utc_instant(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def validate_event_time_range(starts_at: datetime, ends_at: datetime | None) -> None:
    """Reject an event whose end is earlier than its start.

    A missing end is an open-ended event. An end equal to the start is allowed.
    Naive values are treated as UTC, matching the API's UTC instant storage.
    """
    if ends_at is None:
        return
    if _as_utc_instant(ends_at) < _as_utc_instant(starts_at):
        raise ValueError("End time must be at or after the start time.")
