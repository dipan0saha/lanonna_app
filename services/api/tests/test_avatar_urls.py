import uuid
from unittest.mock import patch

import pytest

from lanonna_api.config import settings
from lanonna_api.domain.avatar_urls import (
    normalize_baby_avatar_for_storage,
    normalize_user_avatar_for_storage,
    signed_baby_avatar_urls,
    signed_user_avatar_url,
)
from lanonna_api.domain.errors import InvalidInputError
from lanonna_api.storage import mint_baby_avatar_upload_url, mint_user_avatar_upload_url


def _fake_sign(paths):
    return [f"https://signed/{p}" if p else None for p in paths]


def test_legacy_public_url_for_own_object_is_stored_as_the_path():
    url = f"https://storage.googleapis.com/{settings.display_bucket}/avatars/users/u1/x.webp"
    assert normalize_user_avatar_for_storage(url, "u1") == "avatars/users/u1/x.webp"


@patch("lanonna_api.domain.avatar_urls.signed_display_urls", side_effect=_fake_sign)
def test_signed_user_avatar_url_signs_own_path(_mock_sign):
    assert (
        signed_user_avatar_url("avatars/users/u1/x.jpg", "u1")
        == "https://signed/avatars/users/u1/x.jpg"
    )


@pytest.mark.parametrize(
    "stored",
    [
        "avatars/users/victim/x.jpg",
        "https://example.com/track.png",
        "http://example.com/a.png",
        "smoke/x.jpg",
        "avatars/users/u1/../victim/x.jpg",
        "",
        None,
    ],
)
@patch("lanonna_api.domain.avatar_urls.signed_display_urls", side_effect=_fake_sign)
def test_read_path_never_signs_or_raises_on_unowned_rows(mock_sign, stored):
    assert signed_user_avatar_url(stored, "u1") is None
    mock_sign.assert_called_once_with([None])


@patch("lanonna_api.domain.avatar_urls.signed_display_urls", side_effect=_fake_sign)
def test_signed_baby_avatar_urls_checks_each_rows_own_prefix(mock_sign):
    baby_a = uuid.uuid4()
    baby_b = uuid.uuid4()
    rows = [
        {"id": baby_a, "avatar_url": f"avatars/babies/{baby_a}/1.jpg"},
        {"id": baby_b, "avatar_url": f"avatars/babies/{baby_a}/stolen.jpg"},
        {"id": baby_b, "avatar_url": "https://example.com/x.png"},
    ]
    urls = signed_baby_avatar_urls(rows)
    assert urls == [f"https://signed/avatars/babies/{baby_a}/1.jpg", None, None]
    mock_sign.assert_called_once_with([f"avatars/babies/{baby_a}/1.jpg", None, None])


@patch("lanonna_api.storage._sign_put", return_value={"object_path": "ok"})
def test_minted_user_avatar_is_accepted_by_the_validator(mock_sign):
    mint_user_avatar_upload_url("firebase-uid", byte_length=1000)
    object_name = mock_sign.call_args[0][0]
    assert normalize_user_avatar_for_storage(object_name, "firebase-uid") == object_name


@patch("lanonna_api.storage._sign_put", return_value={"object_path": "ok"})
def test_minted_baby_avatar_is_accepted_by_the_validator(mock_sign):
    baby_id = uuid.uuid4()
    mint_baby_avatar_upload_url(baby_id, byte_length=1000)
    object_name = mock_sign.call_args[0][0]
    assert normalize_baby_avatar_for_storage(object_name, baby_id) == object_name
    with pytest.raises(InvalidInputError):
        normalize_baby_avatar_for_storage(object_name, uuid.uuid4())
