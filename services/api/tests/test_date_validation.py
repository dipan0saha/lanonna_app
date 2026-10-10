from datetime import date, timedelta
from unittest.mock import patch

import pytest

from lanonna_api.domain.date_validation import (
    USER_BIRTH_DATE_MIN,
    validate_actual_birth_date,
    validate_user_birth_date,
)


def test_validate_user_birth_date_rejects_before_floor():
    with pytest.raises(ValueError, match="valid date of birth"):
        validate_user_birth_date(USER_BIRTH_DATE_MIN - timedelta(days=1))


def test_validate_user_birth_date_accepts_floor():
    today = date(2026, 10, 10)
    with patch("lanonna_api.domain.date_validation.utc_today", return_value=today):
        validate_user_birth_date(USER_BIRTH_DATE_MIN)


def test_validate_user_birth_date_rejects_future_beyond_slack():
    today = date(2026, 10, 10)
    with patch("lanonna_api.domain.date_validation.utc_today", return_value=today):
        with pytest.raises(ValueError, match="future"):
            validate_user_birth_date(today + timedelta(days=2))


def test_validate_actual_birth_date_allows_one_day_slack():
    today = date(2026, 10, 10)
    with patch("lanonna_api.domain.date_validation.utc_today", return_value=today):
        validate_actual_birth_date(today + timedelta(days=1))
