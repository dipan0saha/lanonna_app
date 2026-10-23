from datetime import date

import pytest

from lanonna_api.domain.birthdate_vote_window import (
    birthdate_in_vote_window,
    birthdate_vote_bounds,
    validate_birthdate_vote,
)
from lanonna_api.domain.errors import ErrorCode, UnprocessableEntityError


def test_bounds_centered_on_due_date():
    due = date(2027, 1, 15)
    today = date(2026, 10, 1)
    earliest, latest = birthdate_vote_bounds(due, today=today)
    assert earliest == date(2026, 12, 4)
    assert latest == date(2027, 2, 26)


def test_bounds_never_before_today():
    due = date(2026, 10, 10)
    today = date(2026, 10, 20)
    earliest, latest = birthdate_vote_bounds(due, today=today)
    assert earliest == today
    assert latest == date(2026, 11, 21)


def test_validate_rejects_out_of_range():
    due = date(2027, 1, 15)
    today = date(2026, 10, 1)
    with pytest.raises(UnprocessableEntityError) as exc:
        validate_birthdate_vote(date(2099, 12, 31), due, today=today)
    assert exc.value.code == ErrorCode.BIRTHDATE_VOTE_OUT_OF_RANGE


def test_in_window_accepts_due_week():
    due = date(2027, 1, 15)
    today = date(2026, 10, 1)
    assert birthdate_in_vote_window(date(2027, 1, 14), due, today=today)
