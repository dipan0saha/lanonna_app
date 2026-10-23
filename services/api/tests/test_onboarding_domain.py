import uuid
from datetime import date, datetime, timezone
from unittest.mock import patch

import pytest

from lanonna_api.domain.name_suggestions import (
    normalize_gender_for_fun,
    normalize_gender_for_first_moment_seed,
    normalize_suggested_name,
)
from lanonna_api.domain.onboarding import (
    complete_owner_onboarding_for_user,
    seed_expecting_profile_name_suggestions,
    seed_first_moment,
)


def test_normalize_gender_for_fun_rejects_unknown():
    with pytest.raises(ValueError):
        normalize_gender_for_fun("unknown")


def test_first_moment_seed_normalizes_invalid_gender():
    assert normalize_gender_for_first_moment_seed("bogus") == "unknown"


def test_complete_owner_onboarding_requires_email_verified():
    with patch(
        "lanonna_api.domain.onboarding.get_app_user",
        return_value={"display_name": "Alex"},
    ), patch(
        "lanonna_api.domain.onboarding.user_has_self_created_baby",
        return_value=True,
    ):
        with pytest.raises(ValueError, match="Verify your email"):
            complete_owner_onboarding_for_user("uid", email_verified=False)


def test_seed_expecting_profile_name_suggestions_dedupes_and_skips_born():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.onboarding.insert_seed_name_suggestion",
    ) as names:
        created = seed_expecting_profile_name_suggestions(
            "owner",
            baby_id,
            [
                {"name": "Liam", "gender": "male"},
                {"name": "liam", "gender": "female"},
                {"name": "  ", "gender": "male"},
            ],
            baby={"lifecycle_status": "expecting"},
        )
    assert created == 1
    names.assert_called_once()

    with patch(
        "lanonna_api.domain.onboarding.insert_seed_name_suggestion",
    ) as names_born:
        assert (
            seed_expecting_profile_name_suggestions(
                "owner",
                baby_id,
                [{"name": "Mia", "gender": "female"}],
                baby={"lifecycle_status": "born"},
            )
            == 0
        )
    names_born.assert_not_called()


def test_seed_first_moment_skips_blank_names():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.onboarding.require_owner_baby",
            return_value={
                "lifecycle_status": "expecting",
                "expected_birth_date": None,
                "actual_birth_date": None,
            },
        ),
        patch("lanonna_api.domain.onboarding.insert_seed_event") as ev,
        patch("lanonna_api.domain.onboarding.insert_seed_registry_item"),
        patch("lanonna_api.domain.onboarding.insert_seed_name_suggestion") as names,
    ):
        counts = seed_first_moment(
            "owner",
            baby_id,
            [],
            [],
            [{"name": "  ", "gender": "male"}, {"name": "Mia", "gender": "female"}],
        )
    ev.assert_not_called()
    names.assert_called_once()
    assert counts["name_suggestions_created"] == 1
    assert normalize_suggested_name("  Mia  ") == "Mia"


def test_seed_first_moment_expecting_events_use_due_date_offsets_and_catalog_ids():
    baby_id = uuid.uuid4()
    due = date(2027, 1, 20)
    with (
        patch(
            "lanonna_api.domain.onboarding.require_owner_baby",
            return_value={
                "lifecycle_status": "expecting",
                "expected_birth_date": due,
                "actual_birth_date": None,
            },
        ),
        patch("lanonna_api.domain.onboarding.insert_seed_event") as ev,
        patch("lanonna_api.domain.onboarding.insert_seed_registry_item"),
        patch("lanonna_api.domain.onboarding.insert_seed_name_suggestion"),
        patch(
            "lanonna_api.first_moment_presets.utc_today",
            return_value=date(2026, 10, 23),
        ),
    ):
        seed_first_moment(
            "owner",
            baby_id,
            ["gender_reveal", "baby_shower", "due_date"],
            [],
            [],
        )

    assert ev.call_count == 3
    calls = ev.call_args_list
    assert calls[0].kwargs["catalog_suggestion_id"] == "gender_reveal"
    assert calls[0].args[3] == datetime(2027, 1, 6, 12, 0, tzinfo=timezone.utc)
    assert calls[1].kwargs["catalog_suggestion_id"] == "baby_shower"
    assert calls[1].args[3] == datetime(2027, 1, 13, 12, 0, tzinfo=timezone.utc)
    assert calls[2].kwargs["catalog_suggestion_id"] == "due_date"
    assert calls[2].args[3] == datetime(2027, 1, 20, 12, 0, tzinfo=timezone.utc)


def test_seed_first_moment_born_events_use_forward_offsets():
    baby_id = uuid.uuid4()
    birth = date(2026, 5, 1)
    with (
        patch(
            "lanonna_api.domain.onboarding.require_owner_baby",
            return_value={
                "lifecycle_status": "born",
                "expected_birth_date": None,
                "actual_birth_date": birth,
            },
        ),
        patch("lanonna_api.domain.onboarding.insert_seed_event") as ev,
        patch("lanonna_api.domain.onboarding.insert_seed_registry_item"),
        patch("lanonna_api.domain.onboarding.insert_seed_name_suggestion"),
    ):
        seed_first_moment(
            "owner",
            baby_id,
            ["first_checkup"],
            [],
            [],
        )

    ev.assert_called_once()
    assert ev.call_args.kwargs["catalog_suggestion_id"] == "first_checkup"
    assert ev.call_args.args[3] == datetime(2026, 5, 1, 12, 0, tzinfo=timezone.utc)
