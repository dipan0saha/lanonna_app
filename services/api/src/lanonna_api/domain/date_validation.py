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
