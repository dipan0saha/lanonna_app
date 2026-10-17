from datetime import datetime, timezone
from unittest.mock import patch

from lanonna_api.domain.onboarding import onboarding_status_for_user


def test_onboarding_profile_complete_requires_terms():
    row = {
        "display_name": "Sarah Parker",
        "terms_accepted_at": None,
        "owner_onboarding_completed_at": None,
    }
    with (
        patch("lanonna_api.domain.onboarding.get_app_user", return_value=row),
        patch("lanonna_api.domain.onboarding.user_has_owner_baby", return_value=False),
        patch(
            "lanonna_api.domain.onboarding.user_has_baby_membership",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_self_created_baby",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_follower_membership",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.self_created_owner_baby_profile_id",
            return_value=None,
        ),
    ):
        data = onboarding_status_for_user("uid", email_verified=True)
    assert data["profile_complete"] is False

    row["terms_accepted_at"] = datetime.now(timezone.utc)
    with (
        patch("lanonna_api.domain.onboarding.get_app_user", return_value=row),
        patch("lanonna_api.domain.onboarding.user_has_owner_baby", return_value=False),
        patch(
            "lanonna_api.domain.onboarding.user_has_baby_membership",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_self_created_baby",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_follower_membership",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.self_created_owner_baby_profile_id",
            return_value=None,
        ),
    ):
        data = onboarding_status_for_user("uid", email_verified=True)
    assert data["profile_complete"] is True
    assert data["can_access_main_app"] is False


def test_can_access_main_app_false_for_owner_mid_onboarding():
    row = {
        "display_name": "Owner",
        "terms_accepted_at": datetime.now(timezone.utc),
        "owner_onboarding_completed_at": None,
    }
    with (
        patch("lanonna_api.domain.onboarding.get_app_user", return_value=row),
        patch("lanonna_api.domain.onboarding.user_has_owner_baby", return_value=True),
        patch(
            "lanonna_api.domain.onboarding.user_has_baby_membership",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_self_created_baby",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_follower_membership",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.self_created_owner_baby_profile_id",
            return_value=None,
        ),
    ):
        data = onboarding_status_for_user("uid", email_verified=True)
    assert data["profile_complete"] is True
    assert data["needs_owner_onboarding"] is True
    assert data["can_access_main_app"] is False


def test_can_access_main_app_true_for_follower_with_membership():
    row = {
        "display_name": "Follower",
        "terms_accepted_at": datetime.now(timezone.utc),
        "owner_onboarding_completed_at": None,
    }
    with (
        patch("lanonna_api.domain.onboarding.get_app_user", return_value=row),
        patch("lanonna_api.domain.onboarding.user_has_owner_baby", return_value=False),
        patch(
            "lanonna_api.domain.onboarding.user_has_baby_membership",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_self_created_baby",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_follower_membership",
            return_value=True,
        ),
        patch(
            "lanonna_api.domain.onboarding.self_created_owner_baby_profile_id",
            return_value=None,
        ),
    ):
        data = onboarding_status_for_user("uid", email_verified=True)
    assert data["can_access_main_app"] is True


def test_patch_profile_fields_rejects_terms_revocation():
    from lanonna_api.repositories.users import patch_profile_fields

    try:
        patch_profile_fields("uid", {"display_name": "Name", "accept_terms": False})
    except ValueError as exc:
        assert "revoked" in str(exc).lower()
    else:
        raise AssertionError("expected ValueError")
