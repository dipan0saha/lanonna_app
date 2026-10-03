import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.gallery import list_gallery


def test_list_gallery_denied_without_membership():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.get_baby_membership",
        return_value=None,
    ):
        with pytest.raises(PermissionError):
            list_gallery("uid", baby_id)


def test_list_gallery_follower_ready_only():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.gallery.get_baby_membership",
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
        "lanonna_api.domain.gallery.get_baby_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.gallery.list_photos_for_baby",
        return_value=[],
    ) as list_mock:
        list_gallery("uid", baby_id, sort="favorites")
        list_mock.assert_called_once_with(
            baby_id, ready_only=False, limit=50, offset=0, sort="favorites"
        )
