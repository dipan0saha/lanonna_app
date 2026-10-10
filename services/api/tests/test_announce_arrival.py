from datetime import date, timedelta
from unittest.mock import patch
import uuid

import pytest

from lanonna_api.domain.home import announce_arrival, validate_actual_birth_date


def test_validate_actual_birth_date_allows_utc_today():
    today = date(2026, 10, 1)
    with patch("lanonna_api.domain.date_validation.utc_today", return_value=today):
        validate_actual_birth_date(today)


def test_validate_actual_birth_date_allows_one_day_ahead_of_utc():
    today = date(2026, 10, 1)
    with patch("lanonna_api.domain.date_validation.utc_today", return_value=today):
        validate_actual_birth_date(today + timedelta(days=1))


def test_validate_actual_birth_date_rejects_beyond_slack():
    today = date(2026, 10, 1)
    with patch("lanonna_api.domain.date_validation.utc_today", return_value=today):
        with pytest.raises(ValueError, match="future"):
            validate_actual_birth_date(today + timedelta(days=2))


def test_announce_arrival_enqueues_notify_when_expecting():
    baby_id = uuid.uuid4()
    birth = date(2026, 10, 1)
    row = {
        "id": baby_id,
        "name": "River",
        "gender": "unknown",
        "expected_birth_date": date(2026, 9, 1),
        "actual_birth_date": birth,
        "lifecycle_status": "born",
    }
    with (
        patch("lanonna_api.domain.home._utc_today", return_value=birth),
        patch(
            "lanonna_api.domain.home.get_baby_for_owner",
            return_value={"name": "River", "lifecycle_status": "expecting"},
        ),
        patch("lanonna_api.domain.home.update_baby_for_owner", return_value=row),
        patch("lanonna_api.domain.home.insert_activity_event") as activity,
        patch("lanonna_api.domain.home.safe_enqueue_fan_out") as notify,
    ):
        result = announce_arrival("owner_uid", baby_id, birth)

    assert result["lifecycle_status"] == "born"
    assert result["role"] == "owner"
    activity.assert_called_once()
    notify.assert_called_once()


def test_announce_arrival_returns_after_pubsub_failure():
    baby_id = uuid.uuid4()
    birth = date(2026, 10, 1)
    row = {
        "id": baby_id,
        "name": "River",
        "gender": None,
        "expected_birth_date": None,
        "actual_birth_date": birth,
        "lifecycle_status": "born",
    }
    with (
        patch("lanonna_api.domain.home._utc_today", return_value=birth),
        patch(
            "lanonna_api.domain.home.get_baby_for_owner",
            return_value={"name": "River", "lifecycle_status": "expecting"},
        ),
        patch("lanonna_api.domain.home.update_baby_for_owner", return_value=row),
        patch("lanonna_api.domain.home.insert_activity_event"),
        patch(
            "lanonna_api.domain.notifications.publish_notify_fan_out",
            side_effect=RuntimeError("pubsub down"),
        ),
    ):
        result = announce_arrival("owner_uid", baby_id, birth)

    assert result["lifecycle_status"] == "born"
