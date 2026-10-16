from unittest.mock import patch
import uuid

from datetime import date, timedelta

from lanonna_api.domain.home import _build_birth_welcome, _build_home_teasers, build_home_summary


def test_build_home_summary_includes_getting_started_and_next_event():
    baby_id = uuid.uuid4()
    baby = {
        "name": "Parker",
        "lifecycle_status": "expecting",
        "expected_birth_date": "2026-10-08",
    }
    with (
        patch(
            "lanonna_api.domain.home.require_active_membership",
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
            return_value={"recent_photos": [], "upcoming_events": []},
        ),
        patch("lanonna_api.domain.home.list_active_for_user", return_value=[]),
        patch("lanonna_api.domain.home.list_new_followers", return_value=[]),
        patch("lanonna_api.domain.home.list_invitations_for_baby", return_value=[]),
        patch("lanonna_api.domain.home._build_birth_welcome", return_value=None),
    ):
        data = build_home_summary("uid", baby_id)

    assert "storage_usage" not in data
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
        patch("lanonna_api.domain.home.require_active_membership", return_value=baby),
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
            return_value={"recent_photos": [], "upcoming_events": []},
        ),
        patch("lanonna_api.domain.home.list_active_for_user", return_value=[]),
        patch("lanonna_api.domain.home._build_birth_welcome", return_value=None),
    ):
        data = build_home_summary("uid", baby_id)

    assert data["getting_started"] is None
    assert data["next_up_event"]["title"] == "Reveal"
    assert data["family_insight"]["vote_count"] == 3


def test_build_home_teasers_only_recent_photos_and_upcoming_events():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    event_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.home.list_photos_for_baby",
            return_value=[{"id": photo_id, "thumb_path": "thumbs/x.jpg"}],
        ) as list_photos,
        patch(
            "lanonna_api.domain.home.list_events",
            return_value=[
                {
                    "id": event_id,
                    "title": "Shower",
                    "starts_at": "2026-10-02T18:00:00Z",
                    "location": "Home",
                }
            ],
        ) as list_events,
        patch(
            "lanonna_api.domain.home.signed_thumb_url",
            return_value="https://signed/thumb",
        ),
    ):
        data = _build_home_teasers(baby_id)

    assert set(data.keys()) == {"recent_photos", "upcoming_events"}
    assert data["recent_photos"][0]["id"] == str(photo_id)
    assert data["upcoming_events"][0]["title"] == "Shower"
    list_photos.assert_called_once()
    list_events.assert_called_once()


def test_build_birth_welcome_for_follower_when_born():
    baby_id = uuid.uuid4()
    birth = date.today() - timedelta(days=2)
    baby = {
        "name": "Parker",
        "lifecycle_status": "born",
        "actual_birth_date": birth.isoformat(),
    }
    with (
        patch("lanonna_api.domain.home.get_announcement") as get_ann,
        patch("lanonna_api.domain.home._utc_today", return_value=date.today()),
        patch(
            "lanonna_api.domain.home._display_url_for_photo",
            return_value="https://example.com/photo.jpg",
        ),
    ):
        get_ann.return_value = {
            "id": uuid.uuid4(),
            "first_name": "Parker",
            "weight_text": "7 lb 4 oz",
            "photo_id": uuid.uuid4(),
        }
        data = _build_birth_welcome(baby, baby_id, is_owner=False)

    assert data is not None
    assert data["baby_name"] == "Parker"
    assert data["weight_text"] == "7 lb 4 oz"
    assert data["everyone_notified"] is False
    assert data["announcement"]["photo_display_url"].startswith("https://")
