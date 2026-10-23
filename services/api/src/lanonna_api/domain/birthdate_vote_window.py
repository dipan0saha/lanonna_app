"""Birthdate prediction window (FR-GAM-002, #413).

One rule for the vote write, the app's date picker (``birthdate_vote_min`` /
``birthdate_vote_max`` on the predictions payload) and the reads that show
votes (Popular Dates and the home top guess).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any

from lanonna_api.domain.date_validation import utc_today
from lanonna_api.domain.errors import ErrorCode, InvalidInputError

# Six weeks either side of the due date: a plausible guess range.
BIRTHDATE_VOTE_DAYS_AROUND_DUE = 42
# With no due date, guesses may reach a full term (40 weeks) plus two weeks.
BIRTHDATE_VOTE_DAYS_AHEAD_WITHOUT_DUE = 294


@dataclass(frozen=True)
class BirthdateVoteWindow:
    """Inclusive date range; ``None`` leaves that side open."""

    earliest: date | None
    latest: date | None

    def contains(self, value: date) -> bool:
        return (self.earliest is None or value >= self.earliest) and (
            self.latest is None or value <= self.latest
        )


UNBOUNDED_BIRTHDATE_WINDOW = BirthdateVoteWindow(None, None)


def expected_due_date(baby: dict[str, Any]) -> date | None:
    """The baby row's ``expected_birth_date`` as a date (rows may carry ISO text)."""
    value = baby.get("expected_birth_date")
    if value is None or isinstance(value, date):
        return value
    return date.fromisoformat(str(value))


def birthdate_vote_open_window(
    due_date: date | None,
    *,
    today: date | None = None,
) -> BirthdateVoteWindow:
    """Dates a member may pick now: never in the past, six weeks either side of
    the due date. Past the end of that range (still expecting, long overdue)
    only today stays open, so the picker is never empty."""
    reference = today or utc_today()
    if due_date is None:
        return BirthdateVoteWindow(
            reference,
            reference + timedelta(days=BIRTHDATE_VOTE_DAYS_AHEAD_WITHOUT_DUE),
        )
    around = timedelta(days=BIRTHDATE_VOTE_DAYS_AROUND_DUE)
    earliest = max(reference, due_date - around)
    return BirthdateVoteWindow(earliest, max(due_date + around, earliest))


def birthdate_vote_shown_window(
    due_date: date | None,
    *,
    today: date | None = None,
) -> BirthdateVoteWindow:
    """Stored votes that count in Popular Dates and the home top guess.

    No "not in the past" side: a guess that was valid when made keeps counting
    as the days pass. Without a due date only the far side is bounded.
    """
    if due_date is None:
        reference = today or utc_today()
        return BirthdateVoteWindow(
            None,
            reference + timedelta(days=BIRTHDATE_VOTE_DAYS_AHEAD_WITHOUT_DUE),
        )
    around = timedelta(days=BIRTHDATE_VOTE_DAYS_AROUND_DUE)
    return BirthdateVoteWindow(due_date - around, due_date + around)


def validate_birthdate_vote(
    predicted_birth_date: date,
    due_date: date | None,
    *,
    today: date | None = None,
) -> None:
    if not birthdate_vote_open_window(due_date, today=today).contains(
        predicted_birth_date
    ):
        raise InvalidInputError(
            ErrorCode.BIRTHDATE_VOTE_OUT_OF_RANGE,
            "Predicted birth date must be within the allowed window around the due date.",
        )
