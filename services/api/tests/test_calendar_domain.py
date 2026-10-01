from datetime import datetime, timezone

import pytest

from lanonna_api.domain.calendar import _parse_month


def test_parse_month_january():
    start, end = _parse_month("2026-01")
    assert start == datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert end == datetime(2026, 2, 1, tzinfo=timezone.utc)


def test_parse_month_december():
    start, end = _parse_month("2025-12")
    assert start == datetime(2025, 12, 1, tzinfo=timezone.utc)
    assert end == datetime(2026, 1, 1, tzinfo=timezone.utc)


