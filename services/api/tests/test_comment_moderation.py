import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest

from lanonna_api.domain.content_permissions import (
    member_comment_capabilities,
    member_content_can_delete,
)
from lanonna_api.domain.gallery import delete_comment, edit_comment, get_photo_detail


def test_member_comment_capabilities_owner_moderates_follower():
    membership = {"role": "owner"}
    caps = member_comment_capabilities("owner-uid", membership, "follower-uid")
    assert caps == {
        "is_mine": False,
        "can_edit": False,
        "can_delete": True,
    }


def test_member_comment_capabilities_author_on_own_comment():
    membership = {"role": "follower"}
    caps = member_comment_capabilities("author", membership, "author")
    assert caps["is_mine"] is True
    assert caps["can_edit"] is True
    assert caps["can_delete"] is True


def test_member_content_can_delete_follower_cannot_delete_others():
    membership = {"role": "follower"}
    assert member_content_can_delete("a", membership, "b") is False


def test_get_photo_detail_owner_sees_can_delete_on_follower_comment():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    with patch(
        "lanonna_api.domain.gallery.require_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={
            "id": photo_id,
            "status": "ready",
            "created_at": now,
            "caption": None,
            "display_path": None,
            "thumb_path": None,
            "uploader_display_name": "Owner",
        },
    ), patch(
        "lanonna_api.domain.gallery.list_photo_comments",
        return_value=[
            {
                "id": uuid.uuid4(),
                "body": "Hi",
                "author_firebase_uid": "follower-uid",
                "created_at": now,
                "author_display_name": "Follower",
                "author_email": "f@test.com",
            }
        ],
    ), patch("lanonna_api.domain.gallery.caller_squished", return_value=False), patch(
        "lanonna_api.domain.gallery.squish_count", return_value=0
    ), patch(
        "lanonna_api.domain.gallery.list_tagged_babies_for_photo", return_value=[]
    ), patch(
        "lanonna_api.domain.gallery.signed_display_url", return_value=None
    ), patch("lanonna_api.domain.gallery.signed_thumb_url", return_value=None):
        detail = get_photo_detail("owner-uid", baby_id, photo_id)
    assert detail["comments"][0]["can_delete"] is True
    assert detail["comments"][0]["can_edit"] is False
    assert detail["comments"][0]["is_mine"] is False


def test_delete_comment_owner_deletes_follower_comment():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.require_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"id": photo_id, "status": "ready"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_comment",
        return_value={"author_firebase_uid": "follower-uid"},
    ), patch(
        "lanonna_api.domain.gallery.soft_delete_photo_comment",
        return_value=True,
    ) as delete_mock:
        delete_comment("owner-uid", baby_id, photo_id, comment_id)
    delete_mock.assert_called_once_with(photo_id, comment_id)


def test_delete_comment_follower_cannot_delete_other():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"id": photo_id, "status": "ready"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_comment",
        return_value={"author_firebase_uid": "other-follower"},
    ):
        with pytest.raises(PermissionError, match="Cannot delete"):
            delete_comment("follower-a", baby_id, photo_id, comment_id)


def test_edit_comment_owner_cannot_edit_follower_comment():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch("lanonna_api.domain.gallery.require_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"status": "ready"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_comment",
        return_value={"author_firebase_uid": "follower-uid"},
    ):
        with pytest.raises(PermissionError, match="Cannot edit"):
            edit_comment("owner-uid", baby_id, photo_id, comment_id, "Nope")
