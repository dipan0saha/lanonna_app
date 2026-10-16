import uuid
from datetime import datetime, timezone
from unittest.mock import patch

from lanonna_api.domain.gallery import list_gallery


def test_list_gallery_returns_offset_page():
    baby_id = uuid.uuid4()
    created = datetime(2026, 1, 1, tzinfo=timezone.utc)
    rows = [
        {
            "id": uuid.uuid4(),
            "status": "ready",
            "caption": None,
            "created_at": created,
            "thumb_path": None,
            "squish_count": 0,
            "comment_count": 0,
            "uploader_display_name": "Sam",
        }
    ]
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.gallery.list_photos_for_baby",
        return_value=rows,
    ) as list_mock:
        page = list_gallery("uid", baby_id, limit=50, offset=0)
    list_mock.assert_called_once()
    assert list_mock.call_args.kwargs["limit"] == 51
    assert set(page.keys()) == {"items", "offset", "limit", "has_more"}
    assert page["has_more"] is False
    assert len(page["items"]) == 1
