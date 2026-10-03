from unittest.mock import patch
import uuid

from lanonna_api.domain.home import build_home_summary


def test_build_home_summary_includes_getting_started_and_next_event():
    baby_id = uuid.uuid4()
    baby = {
        "name": "Parker",
        "lifecycle_status": "expecting",
        "expected_birth_date": "2026-10-08",
    }
    with (
        patch(
            "lanonna_api.domain.home.get_baby_membership",
            return_value={**baby, "role": "owner"},
        ),
        patch("lanonna_api.domain.home.count_name_suggestions", return_value=2),
        patch("lanonna_api.domain.home.count_gender_votes", return_value=5),
        patch("lanonna_api.domain.home.list_recent_for_baby", return_value=[]),
        patch("lanonna_api.domain.home.gender_vote_totals", return_value={"male": 3, "female": 2}),
        patch("lanonna_api.domain.home.list_name_suggestions", return_value=[{"suggested_name": "Milo", "like_count": 5}]),
        patch("lanonna_api.domain.home.birthdate_vote_histogram", return_value=[]),
        patch(
            "lanonna_api.domain.home.list_events",
            return_value=[{"id": uuid.uuid4(), "title": "Shower", "starts_at": "2026-10-02T18:00:00Z", "location": "Home"}],
        ),
        patch("lanonna_api.domain.home.count_registry_items", return_value=0),
        patch("lanonna_api.domain.home.count_sent_invitations", return_value=0),
        patch("lanonna_api.domain.home.count_follower_memberships", return_value=0),
        patch("lanonna_api.domain.home.count_photos_for_baby", return_value=0),
        patch("lanonna_api.domain.home.count_events", return_value=0),
        patch(
            "lanonna_api.domain.home._build_home_teasers",
            return_value={
                "recent_photos": [],
                "favorite_photos": [],
                "registry_open_count": 0,
                "registry_highlights": [],
                "recent_registry_purchases": [],
                "upcoming_events": [],
                "rsvp_reminders": [],
                "notification_preview": [],
            },
        ),
        patch("lanonna_api.domain.home.list_active_for_user", return_value=[]),
        patch("lanonna_api.domain.home.list_new_followers", return_value=[]),
        patch("lanonna_api.domain.home.list_invitations_for_baby", return_value=[]),
        patch("lanonna_api.domain.home.storage_usage_for_owner_babies", return_value=None),
        patch("lanonna_api.domain.home._build_birth_welcome", return_value=None),
    ):
        data = build_home_summary("uid", baby_id)

    assert data["next_up_event"]["title"] == "Shower"
    assert data["getting_started"]["total"] == 5
    profile_task = next(
        t for t in data["getting_started"]["tasks"] if t["id"] == "baby_profile"
    )
    assert profile_task["deep_link"] == f"/baby/{baby_id}/edit"
    assert data["family_insight"]["top_name"]["suggested_name"] == "Milo"
    assert data["family_insight"]["gender_totals"]["male"] == 3


def test_build_home_summary_follower_omits_getting_started():
    baby_id = uuid.uuid4()
    baby = {
        "name": "Parker",
        "lifecycle_status": "expecting",
        "expected_birth_date": "2026-10-08",
        "role": "follower",
    }
    with (
        patch("lanonna_api.domain.home.get_baby_membership", return_value=baby),
        patch("lanonna_api.domain.home.count_name_suggestions", return_value=0),
        patch("lanonna_api.domain.home.count_gender_votes", return_value=3),
        patch("lanonna_api.domain.home.list_recent_for_baby", return_value=[]),
        patch("lanonna_api.domain.home.gender_vote_totals", return_value={"male": 2, "female": 1}),
        patch("lanonna_api.domain.home.list_name_suggestions", return_value=[]),
        patch("lanonna_api.domain.home.birthdate_vote_histogram", return_value=[]),
        patch(
            "lanonna_api.domain.home.list_events",
            return_value=[{"id": uuid.uuid4(), "title": "Reveal", "starts_at": "2026-10-02T18:00:00Z", "location": None}],
        ),
        patch(
            "lanonna_api.domain.home._build_home_teasers",
            return_value={
                "recent_photos": [],
                "favorite_photos": [],
                "registry_open_count": 0,
                "registry_highlights": [],
                "recent_registry_purchases": [],
                "upcoming_events": [],
                "rsvp_reminders": [],
                "notification_preview": [],
            },
        ),
        patch("lanonna_api.domain.home.list_active_for_user", return_value=[]),
        patch("lanonna_api.domain.home._build_birth_welcome", return_value=None),
    ):
        data = build_home_summary("uid", baby_id)

    assert data["getting_started"] is None
    assert data["next_up_event"]["title"] == "Reveal"
    assert data["family_insight"]["vote_count"] == 3
