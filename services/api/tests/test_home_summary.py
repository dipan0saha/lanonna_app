from unittest.mock import patch
import uuid

from datetime import date, timedelta

from lanonna_api.domain.birthdate_vote_window import birthdate_vote_shown_window
from lanonna_api.domain.home import _build_birth_welcome, _build_home_teasers, build_home_summary


def _counts(**overrides):
    counts = {
        "name_suggestion_count": 0,
        "vote_count": 0,
        "male_votes": 0,
        "female_votes": 0,
        "top_birthdate_guess": None,
        "has_registry_item": False,
        "has_invitation": False,
        "has_follower": False,
        "has_photo": False,
        "has_event": False,
    }
    counts.update(overrides)
    return counts


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
        patch(
            "lanonna_api.domain.home.home_summary_counts",
            return_value=_counts(name_suggestion_count=2, vote_count=5, male_votes=3, female_votes=2),
        ) as counts,
        patch("lanonna_api.domain.home.list_recent_for_baby", return_value=[]),
        patch("lanonna_api.domain.home.list_name_suggestions", return_value=[{"suggested_name": "Milo", "like_count": 5}]) as names,
        patch(
            "lanonna_api.domain.home.list_events",
            return_value=[{"id": uuid.uuid4(), "title": "Shower", "starts_at": "2026-10-02T18:00:00Z", "location": "Home"}],
        ) as events,
        patch(
            "lanonna_api.domain.home._build_home_teasers",
            return_value={"recent_photos": [], "upcoming_events": []},
        ) as teasers,
        patch("lanonna_api.domain.home.list_active_for_user", return_value=[]),
        patch("lanonna_api.domain.home.list_new_followers", return_value=[]),
        patch("lanonna_api.domain.home.list_invitations_for_baby", return_value=[]) as invites,
        patch("lanonna_api.domain.home._build_birth_welcome", return_value=None),
    ):
        data = build_home_summary("uid", baby_id)

    # Every list is bounded in SQL, and upcoming events are read once for
    # both "next up" and the teaser strip.
    names.assert_called_once_with(baby_id, limit=1)
    # The top guess is picked in SQL from the same window Popular Dates uses (#413).
    counts.assert_called_once_with(
        baby_id,
        birthdate_window=birthdate_vote_shown_window(date(2026, 10, 8)),
    )
    events.assert_called_once_with(baby_id, upcoming_only=True, limit=3)
    assert teasers.call_args.args[1] is events.return_value
    invites.assert_called_once_with(baby_id, status="pending", limit=5)
    assert all(t["done"] is False for t in data["getting_started"]["tasks"][1:])

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
        patch(
            "lanonna_api.domain.home.home_summary_counts",
            return_value=_counts(name_suggestion_count=0, vote_count=3, male_votes=2, female_votes=1),
        ),
        patch("lanonna_api.domain.home.list_recent_for_baby", return_value=[]),
        patch("lanonna_api.domain.home.list_name_suggestions", return_value=[]),
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
    upcoming = [
        {
            "id": event_id,
            "title": "Shower",
            "starts_at": "2026-10-02T18:00:00Z",
            "location": "Home",
        }
    ]
    with (
        patch(
            "lanonna_api.domain.home.list_photos_for_baby",
            return_value=[
                {"id": photo_id, "thumb_path": "thumbs/x.jpg"},
                {"id": uuid.uuid4(), "thumb_path": None},
            ],
        ) as list_photos,
        patch(
            "lanonna_api.domain.home.signed_thumb_urls",
            return_value=["https://signed/thumb"],
        ) as sign,
    ):
        data = _build_home_teasers(baby_id, upcoming)

    assert set(data.keys()) == {"recent_photos", "upcoming_events"}
    assert data["recent_photos"] == [{"id": str(photo_id), "thumb_url": "https://signed/thumb"}]
    assert data["upcoming_events"][0]["title"] == "Shower"
    list_photos.assert_called_once_with(baby_id, ready_only=True, limit=4)
    # Thumbs that exist are signed as one batch.
    sign.assert_called_once_with(["thumbs/x.jpg"])


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
            "lanonna_api.domain.home.announcement_photo_display_url",
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
