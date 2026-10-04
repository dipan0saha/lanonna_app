import uuid
from unittest.mock import patch

import pytest
from pydantic import ValidationError

from lanonna_api.domain.gallery import init_photo_upload
from lanonna_api.routers.photos import PhotoInitRequest

_BABY = uuid.uuid4()


def test_photo_init_request_accepts_optional_caption():
    body = PhotoInitRequest(
        baby_profile_id=_BABY,
        byte_length=1000,
        caption="Hello world",
    )
    assert body.caption == "Hello world"


def test_photo_init_request_rejects_long_caption():
    with pytest.raises(ValidationError):
        PhotoInitRequest(
            baby_profile_id=_BABY,
            byte_length=1000,
            caption="x" * 2001,
        )


def test_init_photo_upload_passes_caption_to_create_pending_photo():
    user = {"uid": "uid1", "email": "a@b.com"}
    with patch(
        "lanonna_api.domain.gallery.assert_owner_membership",
    ), patch("lanonna_api.domain.gallery.upsert_app_user"), patch(
        "lanonna_api.domain.gallery.create_pending_photo"
    ) as create, patch(
        "lanonna_api.domain.gallery.mint_display_upload_for_object",
        return_value={
            "upload_url": "https://example/upload",
            "object_path": "display/x.jpg",
            "content_type": "image/jpeg",
            "max_bytes": 2097152,
            "required_headers": {},
            "expires_in_seconds": 900,
        },
    ):
        create.return_value = {
            "id": uuid.uuid4(),
            "display_path": "display/x.jpg",
        }
        init_photo_upload(
            user,
            _BABY,
            "image/jpeg",
            1200,
            caption="First day",
        )
        create.assert_called_once()
        assert create.call_args[0][4] == "First day"
