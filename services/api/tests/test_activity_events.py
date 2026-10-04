import uuid
from datetime import datetime, timezone
from unittest.mock import patch

from lanonna_api.domain.home import list_activity_events


def test_list_activity_events_gallery_scope_filters_types():
    baby_id = uuid.uuid4()
    rows = [
        {
            "id": uuid.uuid4(),
            "event_type": "photo_squish",
            "summary": 'Sue squished "a photo"',
            "created_at": datetime.now(timezone.utc),
            "payload": {"photo_id": str(uuid.uuid4())},
            "actor_firebase_uid": "uid-1",
            "actor_display_name": "Sue",
        }
    ]
    with patch(
        "lanonna_api.domain.home.get_baby_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.home.list_recent_for_baby",
        return_value=rows,
    ) as list_mock:
        result = list_activity_events("uid-1", baby_id, scope="gallery")
        list_mock.assert_called_once()
        assert set(list_mock.call_args.kwargs["event_types"]) == {
            "photo_squish",
            "photo_comment",
        }
        assert result["items"][0]["actor_display_name"] == "Sue"
        assert result["items"][0]["photo_id"] is not None


def test_list_activity_events_all_scope_no_type_filter():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.home.get_baby_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.home.list_recent_for_baby",
        return_value=[],
    ) as list_mock:
        list_activity_events("uid-1", baby_id, scope="all")
        assert list_mock.call_args.kwargs["event_types"] is None
