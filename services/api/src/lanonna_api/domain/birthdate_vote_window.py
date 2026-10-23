"""Valid calendar window for birthdate prediction votes (FR-GAM-002, #413)."""

from __future__ import annotations

from datetime import date, timedelta

from lanonna_api.domain.date_validation import utc_today
from lanonna_api.domain.errors import ErrorCode, UnprocessableEntityError

# Six weeks before/after due — plausible guess range for expecting babies.
BIRTHDATE_VOTE_DAYS_BEFORE_DUE = 42
BIRTHDATE_VOTE_DAYS_AFTER_DUE = 42
DEFAULT_DUE_OFFSET_DAYS = 90


def _due_anchor(due_date: date | None, today: date) -> date:
    if due_date is not None:
        return due_date
    return today + timedelta(days=DEFAULT_DUE_OFFSET_DAYS)


def birthdate_vote_bounds(
    due_date: date | None,
    *,
    today: date | None = None,
) -> tuple[date, date]:
    """Inclusive min/max dates for a birthdate guess."""
    anchor = today or utc_today()
    due = _due_anchor(due_date, anchor)
    earliest = max(anchor, due - timedelta(days=BIRTHDATE_VOTE_DAYS_BEFORE_DUE))
    latest = due + timedelta(days=BIRTHDATE_VOTE_DAYS_AFTER_DUE)
    return earliest, latest


def birthdate_in_vote_window(
    predicted: date,
    due_date: date | None,
    *,
    today: date | None = None,
) -> bool:
    earliest, latest = birthdate_vote_bounds(due_date, today=today)
    return earliest <= predicted <= latest


def validate_birthdate_vote(
    predicted_birth_date: date,
    due_date: date | None,
    *,
    today: date | None = None,
) -> None:
    if not birthdate_in_vote_window(predicted_birth_date, due_date, today=today):
        raise UnprocessableEntityError(
            ErrorCode.BIRTHDATE_VOTE_OUT_OF_RANGE,
            "Predicted birth date must be within the allowed window around the due date.",
        )
