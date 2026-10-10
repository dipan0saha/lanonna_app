from datetime import datetime, timezone
from unittest.mock import patch

from lanonna_api.domain.onboarding import onboarding_status_for_user
from lanonna_api.repositories.babies import create_baby_with_owner_membership


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
    ):
        data = onboarding_status_for_user("uid", email_verified=True)
    assert data["profile_complete"] is True
    assert data["can_access_main_app"] is False


def test_create_baby_persists_relationship_label():
    executed: list[tuple] = []

    class FakeCursor:
        def fetchone(self):
            return {
                "id": "00000000-0000-0000-0000-000000000001",
                "name": "Baby",
                "gender": "male",
                "expected_birth_date": None,
                "actual_birth_date": None,
                "lifecycle_status": "expecting",
                "created_at": datetime.now(timezone.utc),
            }

    class FakeConn:
        def execute(self, sql, params):
            executed.append((sql.strip(), params))
            return FakeCursor()

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

    with patch(
        "lanonna_api.repositories.babies.get_connection",
        return_value=FakeConn(),
    ):
        result = create_baby_with_owner_membership(
            "owner-uid",
            "Baby",
            "male",
            None,
            None,
            "expecting",
            "Mother",
        )

    assert result["relationship_label"] == "Mother"
    membership_sql = executed[1][0]
    assert "relationship_label" in membership_sql
    assert executed[1][1][2] == "Mother"


def test_update_profile_rejects_terms_revocation():
    from lanonna_api.repositories.users import update_profile

    try:
        update_profile("uid", "Name", accept_terms=False)
    except ValueError as exc:
        assert "revoked" in str(exc).lower()
    else:
        raise AssertionError("expected ValueError")
