"""Onboarding main-app access (#31): creator vs invited owner vs follower."""

import uuid
from datetime import datetime, timezone
from unittest.mock import patch

from lanonna_api.domain.onboarding import onboarding_status_for_user

_USER_ROW = {
    "display_name": "Test User",
    "terms_accepted_at": datetime.now(timezone.utc),
    "owner_onboarding_completed_at": None,
}


def _status(
    *,
    has_owner_baby: bool = False,
    has_baby_membership: bool = False,
    has_self_created_baby: bool = False,
    has_follower_membership: bool = False,
    owner_onboarding_completed_at=None,
    owner_onboarding_baby_profile_id=None,
):
    row = {**_USER_ROW, "owner_onboarding_completed_at": owner_onboarding_completed_at}
    with (
        patch("lanonna_api.domain.onboarding.get_app_user", return_value=row),
        patch(
            "lanonna_api.domain.onboarding.user_has_owner_baby",
            return_value=has_owner_baby,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_baby_membership",
            return_value=has_baby_membership,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_self_created_baby",
            return_value=has_self_created_baby,
        ),
        patch(
            "lanonna_api.domain.onboarding.user_has_follower_membership",
            return_value=has_follower_membership,
        ),
        patch(
            "lanonna_api.domain.onboarding.self_created_owner_baby_profile_id",
            return_value=owner_onboarding_baby_profile_id,
        ),
    ):
        return onboarding_status_for_user("uid", email_verified=True)


def test_follower_only_can_access_main_app():
    data = _status(has_baby_membership=True, has_follower_membership=True)
    assert data["needs_owner_onboarding"] is False
    assert data["can_access_main_app"] is True


def test_creator_mid_onboarding_blocked():
    baby_id = uuid.uuid4()
    data = _status(
        has_owner_baby=True,
        has_baby_membership=True,
        has_self_created_baby=True,
        owner_onboarding_baby_profile_id=baby_id,
    )
    assert data["needs_owner_onboarding"] is True
    assert data["can_access_main_app"] is False
    assert data["owner_onboarding_baby_profile_id"] == baby_id


def test_co_owner_via_invite_can_access_without_creator_onboarding():
    data = _status(
        has_owner_baby=True,
        has_baby_membership=True,
        has_self_created_baby=False,
        has_follower_membership=True,
        owner_onboarding_baby_profile_id=None,
    )
    assert data["needs_owner_onboarding"] is False
    assert data["can_access_main_app"] is True
    assert data["owner_onboarding_baby_profile_id"] is None


def test_invited_owner_only_without_follower_role_can_access():
    data = _status(
        has_owner_baby=True,
        has_baby_membership=True,
        has_self_created_baby=False,
        has_follower_membership=False,
    )
    assert data["needs_owner_onboarding"] is False
    assert data["can_access_main_app"] is True


def test_follower_who_also_created_baby_keeps_main_app_access():
    data = _status(
        has_owner_baby=True,
        has_baby_membership=True,
        has_self_created_baby=True,
        has_follower_membership=True,
    )
    assert data["needs_owner_onboarding"] is True
    assert data["can_access_main_app"] is True


def test_owner_onboarding_completed_always_can_access():
    data = _status(
        has_owner_baby=True,
        has_baby_membership=True,
        has_self_created_baby=True,
        owner_onboarding_completed_at=datetime.now(timezone.utc),
    )
    assert data["needs_owner_onboarding"] is False
    assert data["can_access_main_app"] is True
