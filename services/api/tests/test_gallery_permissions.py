import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest

from lanonna_api.domain.gallery import get_photo_detail, list_gallery


def test_list_gallery_denied_without_membership():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        side_effect=PermissionError("Baby membership required."),
    ):
        with pytest.raises(PermissionError):
            list_gallery("uid", baby_id)


def test_list_gallery_membership_ended():
    from lanonna_api.domain.member_errors import MemberLifecycleError

    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        side_effect=MemberLifecycleError(
            "membership_ended",
            "You no longer have access to this baby profile.",
        ),
    ):
        with pytest.raises(MemberLifecycleError) as exc:
            list_gallery("uid", baby_id)
    assert exc.value.code == "membership_ended"


def test_list_gallery_follower_ready_only():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.gallery.list_photos_for_baby",
        return_value=[],
    ) as list_mock:
        list_gallery("uid", baby_id)
        list_mock.assert_called_once_with(
            baby_id, ready_only=True, limit=50, offset=0, sort="default"
        )


def test_list_gallery_passes_favorites_sort():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.gallery.list_photos_for_baby",
        return_value=[],
    ) as list_mock:
        list_gallery("uid", baby_id, sort="favorites")
        list_mock.assert_called_once_with(
            baby_id, ready_only=False, limit=50, offset=0, sort="favorites"
        )


def test_get_photo_detail_tagged_babies_scoped_to_viewer():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    viewer_uid = "follower-uid"
    created = datetime(2026, 10, 1, tzinfo=timezone.utc)
    photo_row = {
        "id": photo_id,
        "status": "ready",
        "caption": "Bump",
        "created_at": created,
        "display_path": "display/x.jpg",
        "thumb_path": "thumbnails/x.jpg",
        "uploader_display_name": "Owner",
    }
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value=photo_row,
    ), patch(
        "lanonna_api.domain.gallery.list_photo_comments",
        return_value=[],
    ), patch(
        "lanonna_api.domain.gallery.caller_squished",
        return_value=False,
    ), patch(
        "lanonna_api.domain.gallery.squish_count",
        return_value=0,
    ), patch(
        "lanonna_api.domain.gallery.signed_display_url",
        return_value="https://display",
    ), patch(
        "lanonna_api.domain.gallery.signed_thumb_url",
        return_value="https://thumb",
    ), patch(
        "lanonna_api.domain.gallery.list_tagged_babies_for_photo",
        return_value=[],
    ) as tags_mock:
        detail = get_photo_detail(viewer_uid, baby_id, photo_id)
        tags_mock.assert_called_once_with(photo_id, viewer_uid)
        assert detail["tagged_babies"] == []


def test_get_photo_detail_owner_sees_tagged_babies_they_belong_to():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    sibling_id = uuid.uuid4()
    owner_uid = "owner-uid"
    created = datetime(2026, 10, 1, tzinfo=timezone.utc)
    photo_row = {
        "id": photo_id,
        "status": "ready",
        "caption": None,
        "created_at": created,
        "display_path": None,
        "thumb_path": None,
        "uploader_display_name": "Owner",
    }
    with patch(
        "lanonna_api.domain.gallery.require_active_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value=photo_row,
    ), patch(
        "lanonna_api.domain.gallery.list_photo_comments",
        return_value=[],
    ), patch(
        "lanonna_api.domain.gallery.caller_squished",
        return_value=False,
    ), patch(
        "lanonna_api.domain.gallery.squish_count",
        return_value=0,
    ), patch(
        "lanonna_api.domain.gallery.signed_display_url",
        return_value=None,
    ), patch(
        "lanonna_api.domain.gallery.signed_thumb_url",
        return_value=None,
    ), patch(
        "lanonna_api.domain.gallery.list_tagged_babies_for_photo",
        return_value=[
            {"id": sibling_id, "name": "Jordan"},
        ],
    ):
        detail = get_photo_detail(owner_uid, baby_id, photo_id)
        assert detail["tagged_babies"] == [
            {"id": str(sibling_id), "name": "Jordan"},
        ]
