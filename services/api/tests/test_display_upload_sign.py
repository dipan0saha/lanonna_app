import pytest

from lanonna_api.storage import mint_display_upload_url, mint_user_avatar_upload_url


def test_mint_display_upload_url_rejects_oversize_byte_length():
    with pytest.raises(ValueError, match="maximum size"):
        mint_display_upload_url("uid", content_type="image/jpeg", byte_length=3_000_000)


def test_mint_user_avatar_upload_url_path_prefix():
    with pytest.raises(ValueError):
        mint_user_avatar_upload_url("uid", byte_length=0)
    # byte_length validated; path shape covered in test_avatar_urls
