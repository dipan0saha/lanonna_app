from unittest.mock import patch

import pytest

from lanonna_api.domain.avatar_urls import (
    gcs_object_path_from_stored,
    normalize_avatar_for_storage,
    signed_avatar_url,
)
from lanonna_api.storage import mint_baby_avatar_upload_url, mint_user_avatar_upload_url


@patch("lanonna_api.config.settings.display_bucket", "lanonna-dev-display")
def test_gcs_object_path_from_legacy_public_url():
    url = "https://storage.googleapis.com/lanonna-dev-display/smoke/uid/abc.jpg"
    assert gcs_object_path_from_stored(url) == "smoke/uid/abc.jpg"


@patch("lanonna_api.config.settings.display_bucket", "lanonna-dev-display")
def test_normalize_strips_public_url_to_path():
    url = "https://storage.googleapis.com/lanonna-dev-display/avatars/users/u1/x.webp"
    assert normalize_avatar_for_storage(url) == "avatars/users/u1/x.webp"


def test_normalize_external_oauth_url_unchanged():
    oauth = "https://lh3.googleusercontent.com/a/photo"
    assert normalize_avatar_for_storage(oauth) == oauth


@patch("lanonna_api.domain.avatar_urls.signed_display_url", return_value="https://signed/read")
def test_signed_avatar_url_for_object_path(_mock_sign):
    assert signed_avatar_url("avatars/users/u1/x.jpg") == "https://signed/read"


def test_signed_avatar_url_passthrough_oauth():
    oauth = "https://lh3.googleusercontent.com/a/photo"
    assert signed_avatar_url(oauth) == oauth


@patch("lanonna_api.storage._sign_put", return_value={"object_path": "ok"})
def test_mint_user_avatar_upload_uses_avatars_prefix(mock_sign):
    mint_user_avatar_upload_url("firebase-uid", byte_length=1000)
    object_name = mock_sign.call_args[0][0]
    assert object_name.startswith("avatars/users/firebase-uid/")


@patch("lanonna_api.storage._sign_put", return_value={"object_path": "ok"})
def test_mint_baby_avatar_upload_uses_baby_prefix(mock_sign):
    import uuid

    baby_id = uuid.uuid4()
    mint_baby_avatar_upload_url(baby_id, byte_length=1000)
    object_name = mock_sign.call_args[0][0]
    assert object_name.startswith(f"avatars/babies/{baby_id}/")


def test_mint_user_avatar_upload_rejects_oversize_byte_length():
    with pytest.raises(ValueError, match="maximum size"):
        mint_user_avatar_upload_url(
            "uid",
            content_type="image/jpeg",
            byte_length=3_000_000,
        )
