from datetime import date

import pytest

from lanonna_api.domain.birthdate_vote_window import (
    BirthdateVoteWindow,
    birthdate_vote_open_window,
    birthdate_vote_shown_window,
    expected_due_date,
    validate_birthdate_vote,
)
from lanonna_api.domain.errors import ErrorCode, InvalidInputError

_DUE = date(2027, 1, 15)


def test_open_window_is_six_weeks_either_side_of_due():
    window = birthdate_vote_open_window(_DUE, today=date(2026, 10, 1))
    assert window == BirthdateVoteWindow(date(2026, 12, 4), date(2027, 2, 26))


def test_open_window_never_starts_before_today():
    window = birthdate_vote_open_window(date(2026, 10, 10), today=date(2026, 10, 20))
    assert window == BirthdateVoteWindow(date(2026, 10, 20), date(2026, 11, 21))


def test_open_window_long_overdue_keeps_today_open():
    today = date(2026, 12, 1)
    window = birthdate_vote_open_window(date(2026, 10, 1), today=today)
    assert window == BirthdateVoteWindow(today, today)


def test_open_window_without_due_date_reaches_a_full_term():
    today = date(2026, 10, 1)
    window = birthdate_vote_open_window(None, today=today)
    assert window == BirthdateVoteWindow(today, date(2027, 7, 22))


def test_shown_window_keeps_guesses_that_are_now_in_the_past():
    # Valid when made; the day has passed but the guess still counts.
    window = birthdate_vote_shown_window(date(2026, 10, 10), today=date(2026, 10, 20))
    assert window == BirthdateVoteWindow(date(2026, 8, 29), date(2026, 11, 21))
    assert window.contains(date(2026, 10, 1))
    assert not window.contains(date(2099, 12, 31))
    assert not window.contains(date(2020, 1, 1))


def test_shown_window_without_due_date_bounds_only_the_far_side():
    window = birthdate_vote_shown_window(None, today=date(2026, 10, 1))
    assert window.earliest is None
    assert window.contains(date(2026, 1, 1))
    assert not window.contains(date(2099, 12, 31))


def test_validate_rejects_out_of_range_with_400_code():
    with pytest.raises(InvalidInputError) as exc:
        validate_birthdate_vote(date(2099, 12, 31), _DUE, today=date(2026, 10, 1))
    assert exc.value.code == ErrorCode.BIRTHDATE_VOTE_OUT_OF_RANGE
    with pytest.raises(InvalidInputError):
        validate_birthdate_vote(date(2026, 9, 30), _DUE, today=date(2026, 10, 1))


def test_validate_accepts_window_edges():
    today = date(2026, 10, 1)
    validate_birthdate_vote(date(2026, 12, 4), _DUE, today=today)
    validate_birthdate_vote(date(2027, 2, 26), _DUE, today=today)


def test_expected_due_date_reads_date_or_iso_text():
    assert expected_due_date({"expected_birth_date": _DUE}) == _DUE
    assert expected_due_date({"expected_birth_date": "2027-01-15"}) == _DUE
    assert expected_due_date({}) is None
