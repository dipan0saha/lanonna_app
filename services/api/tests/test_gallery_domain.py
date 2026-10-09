import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.gallery import (
    add_comment,
    edit_comment,
    get_photo_detail,
    set_photo_baby_tags,
    squish_photo,
)


def test_edit_comment_rejects_empty_body():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch("lanonna_api.domain.gallery.require_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"status": "ready"},
    ):
        with pytest.raises(ValueError, match="Comment body required"):
            edit_comment("uid", baby_id, photo_id, comment_id, "   ")


def test_edit_comment_not_found_when_update_returns_none():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch("lanonna_api.domain.gallery.require_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"status": "ready"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_comment",
        return_value={"author_firebase_uid": "uid"},
    ), patch(
        "lanonna_api.domain.gallery.update_photo_comment",
        return_value=None,
    ):
        with pytest.raises(LookupError, match="Comment not found"):
            edit_comment("uid", baby_id, photo_id, comment_id, "Updated")


def test_set_photo_tags_rejects_unknown_baby():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    other = uuid.uuid4()
    with patch("lanonna_api.domain.gallery.assert_owner_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"id": photo_id},
    ), patch(
        "lanonna_api.domain.gallery.list_babies_for_user",
        return_value=[{"id": str(baby_id)}],
    ):
        with pytest.raises(PermissionError, match="Cannot tag"):
            set_photo_baby_tags("uid", baby_id, photo_id, [other])


def test_set_photo_baby_tags_happy_path():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    tag_id = uuid.uuid4()
    with patch("lanonna_api.domain.gallery.assert_owner_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"id": photo_id},
    ), patch(
        "lanonna_api.domain.gallery.list_babies_for_user",
        return_value=[{"id": str(baby_id)}, {"id": str(tag_id)}],
    ), patch(
        "lanonna_api.domain.gallery.replace_photo_baby_tags",
    ) as replace_mock, patch(
        "lanonna_api.domain.gallery.list_tagged_babies_for_photo",
        return_value=[{"id": tag_id, "name": "Sibling"}],
    ) as tags_mock:
        result = set_photo_baby_tags("uid", baby_id, photo_id, [tag_id, tag_id])
        replace_mock.assert_called_once_with(photo_id, [tag_id])
        tags_mock.assert_called_once_with(photo_id, "uid")
        assert result["tagged_babies"][0]["name"] == "Sibling"


def test_set_photo_baby_tags_clears_with_empty_list():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    with patch("lanonna_api.domain.gallery.assert_owner_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value={"id": photo_id},
    ), patch(
        "lanonna_api.domain.gallery.list_babies_for_user",
        return_value=[{"id": str(baby_id)}],
    ), patch(
        "lanonna_api.domain.gallery.replace_photo_baby_tags",
    ) as replace_mock, patch(
        "lanonna_api.domain.gallery.list_tagged_babies_for_photo",
        return_value=[],
    ):
        set_photo_baby_tags("uid", baby_id, photo_id, [])
        replace_mock.assert_called_once_with(photo_id, [])


def test_squish_photo_inserts_activity_when_active():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    photo_row = {
        "status": "ready",
        "caption": "First ultrasound",
        "uploader_firebase_uid": "owner-uid",
    }
    with patch("lanonna_api.domain.gallery.require_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value=photo_row,
    ), patch(
        "lanonna_api.domain.gallery.toggle_squish",
        return_value=True,
    ), patch(
        "lanonna_api.domain.gallery.actor_display_name",
        return_value="Grandma Sue",
    ), patch(
        "lanonna_api.domain.gallery.insert_activity_event",
    ) as activity_mock, patch(
        "lanonna_api.domain.gallery.safe_enqueue_notify_user",
    ):
        squish_photo("uid", baby_id, photo_id)
        activity_mock.assert_called_once()
        assert activity_mock.call_args[0][2] == "photo_squish"
        assert "Grandma Sue" in activity_mock.call_args[0][3]
        assert "First ultrasound" in activity_mock.call_args[0][3]


def test_add_comment_inserts_activity():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    photo_row = {
        "status": "ready",
        "caption": "Bump update",
        "uploader_firebase_uid": "owner-uid",
    }
    with patch("lanonna_api.domain.gallery.require_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value=photo_row,
    ), patch(
        "lanonna_api.domain.gallery.upsert_app_user",
    ), patch(
        "lanonna_api.domain.gallery.insert_photo_comment",
        return_value={
            "id": uuid.uuid4(),
            "body": "Nice!",
            "created_at": __import__("datetime").datetime(
                2026, 10, 1, tzinfo=__import__("datetime").timezone.utc
            ),
        },
    ), patch(
        "lanonna_api.domain.gallery.actor_display_name",
        return_value="Aunt Carol",
    ), patch(
        "lanonna_api.domain.gallery.insert_activity_event",
    ) as activity_mock, patch(
        "lanonna_api.domain.gallery.safe_enqueue_notify_user",
    ):
        add_comment("uid", baby_id, photo_id, "Nice!")
        activity_mock.assert_called_once()
        assert activity_mock.call_args[0][2] == "photo_comment"
        assert "Aunt Carol" in activity_mock.call_args[0][3]
        assert "Bump update" in activity_mock.call_args[0][3]


def test_squish_photo_succeeds_when_notify_enqueue_fails():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    photo_row = {
        "status": "ready",
        "caption": "First ultrasound",
        "uploader_firebase_uid": "owner-uid",
    }
    with patch("lanonna_api.domain.gallery.require_membership"), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value=photo_row,
    ), patch(
        "lanonna_api.domain.gallery.toggle_squish",
        return_value=True,
    ), patch(
        "lanonna_api.domain.gallery.actor_display_name",
        return_value="Grandma Sue",
    ), patch(
        "lanonna_api.domain.gallery.insert_activity_event",
    ), patch(
        "lanonna_api.domain.notifications.publish_notify_user",
        side_effect=RuntimeError("pubsub down"),
    ):
        result = squish_photo("squish-uid", baby_id, photo_id)
    assert result == {"squished": True}


def test_get_photo_detail_comment_uses_author_display_name():
    baby_id = uuid.uuid4()
    photo_id = uuid.uuid4()
    photo_row = {
        "id": photo_id,
        "status": "ready",
        "caption": None,
        "created_at": __import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        "display_path": "display/x.jpg",
        "thumb_path": "thumb/x.jpg",
        "uploader_display_name": "Owner",
    }
    comment_row = {
        "id": uuid.uuid4(),
        "body": "Nice!",
        "author_firebase_uid": "author-uid",
        "created_at": photo_row["created_at"],
        "updated_at": None,
        "author_display_name": "Sarah QA",
    }
    with patch(
        "lanonna_api.domain.gallery.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.gallery.get_photo_for_baby",
        return_value=photo_row,
    ), patch(
        "lanonna_api.domain.gallery.list_photo_comments",
        return_value=[comment_row],
    ), patch(
        "lanonna_api.domain.gallery.caller_squished",
        return_value=False,
    ), patch(
        "lanonna_api.domain.gallery.squish_count",
        return_value=0,
    ), patch(
        "lanonna_api.domain.gallery.list_tagged_babies_for_photo",
        return_value=[],
    ), patch(
        "lanonna_api.domain.gallery.signed_display_url",
        return_value="https://example.com/x.jpg",
    ), patch(
        "lanonna_api.domain.gallery.signed_thumb_url",
        return_value="https://example.com/t.jpg",
    ):
        detail = get_photo_detail("viewer", baby_id, photo_id)

    assert detail["comments"][0]["author_display_name"] == "Sarah QA"
