import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.gallery import edit_comment, set_photo_baby_tags


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
    ):
        result = set_photo_baby_tags("uid", baby_id, photo_id, [tag_id, tag_id])
        replace_mock.assert_called_once_with(photo_id, [tag_id])
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
