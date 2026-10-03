from datetime import date, timedelta
from unittest.mock import patch

import pytest

from lanonna_api.domain.home import validate_actual_birth_date


def test_validate_actual_birth_date_allows_utc_today():
    today = date(2026, 10, 1)
    with patch("lanonna_api.domain.home._utc_today", return_value=today):
        validate_actual_birth_date(today)


def test_validate_actual_birth_date_allows_one_day_ahead_of_utc():
    today = date(2026, 10, 1)
    with patch("lanonna_api.domain.home._utc_today", return_value=today):
        validate_actual_birth_date(today + timedelta(days=1))


def test_validate_actual_birth_date_rejects_beyond_slack():
    today = date(2026, 10, 1)
    with patch("lanonna_api.domain.home._utc_today", return_value=today):
        with pytest.raises(ValueError, match="future"):
            validate_actual_birth_date(today + timedelta(days=2))
