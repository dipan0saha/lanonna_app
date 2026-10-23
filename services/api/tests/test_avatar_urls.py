import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.errors import UnprocessableInputError

from lanonna_api.domain.avatar_urls import (
    gcs_object_path_from_stored,
    normalize_baby_avatar_for_storage,
    normalize_user_avatar_for_storage,
    signed_baby_avatar_urls_from_rows,
    signed_user_avatar_url,
)
from lanonna_api.storage import mint_baby_avatar_upload_url, mint_user_avatar_upload_url


def _fake_sign(paths):
    return [
        f"https://signed/{p}" if p else None for p in paths
    ]


def test_gcs_object_path_from_legacy_public_url():
    url = "https://storage.googleapis.com/lanonna-dev-display/avatars/users/u1/x.webp"
    assert gcs_object_path_from_stored(url) == "avatars/users/u1/x.webp"


def test_normalize_strips_public_url_to_path_for_owner():
    url = "https://storage.googleapis.com/lanonna-dev-display/avatars/users/u1/x.webp"
    assert normalize_user_avatar_for_storage(url, "u1") == "avatars/users/u1/x.webp"


@patch("lanonna_api.domain.avatar_urls.signed_display_urls", side_effect=_fake_sign)
def test_signed_user_avatar_url_for_owned_object_path(_mock_sign):
    assert (
        signed_user_avatar_url("avatars/users/u1/x.jpg", "u1")
        == "https://signed/avatars/users/u1/x.jpg"
    )


@patch("lanonna_api.domain.avatar_urls.signed_display_urls", side_effect=_fake_sign)
def test_signed_user_avatar_does_not_sign_other_users_path(_mock_sign):
    assert signed_user_avatar_url("avatars/users/victim/x.jpg", "u1") is None
    _mock_sign.assert_called_once_with([None])


@patch("lanonna_api.domain.avatar_urls.signed_display_urls", side_effect=_fake_sign)
def test_signed_baby_avatar_urls_batch_per_row_owner(mock_sign):
    baby_a = uuid.uuid4()
    baby_b = uuid.uuid4()
    rows = [
        {"id": baby_a, "avatar_url": f"avatars/babies/{baby_a}/1.jpg"},
        {"id": baby_b, "avatar_url": f"avatars/babies/{baby_a}/stolen.jpg"},
    ]
    urls = signed_baby_avatar_urls_from_rows(rows)
    assert urls[0] == f"https://signed/avatars/babies/{baby_a}/1.jpg"
    assert urls[1] is None
    mock_sign.assert_called_once_with(
        [f"avatars/babies/{baby_a}/1.jpg", None],
    )


@patch("lanonna_api.storage._sign_put", return_value={"object_path": "ok"})
def test_mint_user_avatar_upload_uses_avatars_prefix(mock_sign):
    mint_user_avatar_upload_url("firebase-uid", byte_length=1000)
    object_name = mock_sign.call_args[0][0]
    assert object_name.startswith("avatars/users/firebase-uid/")


@patch("lanonna_api.storage._sign_put", return_value={"object_path": "ok"})
def test_mint_baby_avatar_upload_uses_baby_prefix(mock_sign):
    baby_id = uuid.uuid4()
    mint_baby_avatar_upload_url(baby_id, byte_length=1000)
    object_name = mock_sign.call_args[0][0]
    assert object_name.startswith(f"avatars/babies/{baby_id}/")


def test_normalize_baby_avatar_rejects_wrong_baby():
    baby_id = uuid.uuid4()
    other = uuid.uuid4()

    with pytest.raises(UnprocessableInputError):
        normalize_baby_avatar_for_storage(
            f"avatars/babies/{other}/x.jpg",
            baby_id,
        )
