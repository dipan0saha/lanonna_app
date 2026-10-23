import uuid

import pytest

from lanonna_api.domain.errors import ErrorCode, UnprocessableInputError
from lanonna_api.domain.storage_references import (
    avatar_object_path_authorized,
    display_object_path_from_client_value,
    normalize_owned_avatar_for_storage,
)


def test_display_path_from_legacy_public_url():
    url = "https://storage.googleapis.com/lanonna-dev-display/avatars/users/u1/x.webp"
    assert display_object_path_from_client_value(url) == "avatars/users/u1/x.webp"


def test_normalize_owned_user_avatar_accepts_own_path():
    path = "avatars/users/uid-1/abc.webp"
    assert (
        normalize_owned_avatar_for_storage(
            path, owner_kind="user", owner_id="uid-1"
        )
        == path
    )


def test_normalize_rejects_other_users_avatar_path():
    with pytest.raises(UnprocessableInputError) as exc:
        normalize_owned_avatar_for_storage(
            "avatars/users/victim/secret.jpg",
            owner_kind="user",
            owner_id="attacker",
        )
    assert exc.value.code == ErrorCode.INVALID_STORAGE_REFERENCE


def test_normalize_rejects_external_https():
    with pytest.raises(UnprocessableInputError):
        normalize_owned_avatar_for_storage(
            "https://example.com/track.png",
            owner_kind="user",
            owner_id="uid-1",
        )


def test_normalize_rejects_plain_http():
    with pytest.raises(UnprocessableInputError):
        normalize_owned_avatar_for_storage(
            "http://example.com/a.png",
            owner_kind="user",
            owner_id="uid-1",
        )


def test_normalize_rejects_smoke_prefix():
    with pytest.raises(UnprocessableInputError):
        normalize_owned_avatar_for_storage(
            "smoke/uid/abc.jpg",
            owner_kind="user",
            owner_id="uid",
        )


def test_normalize_baby_avatar_requires_baby_prefix():
    baby_id = uuid.uuid4()
    path = f"avatars/babies/{baby_id}/pic.jpg"
    assert (
        normalize_owned_avatar_for_storage(
            path, owner_kind="baby", owner_id=str(baby_id)
        )
        == path
    )


def test_authorize_returns_none_for_cross_account_stored_path():
    assert (
        avatar_object_path_authorized(
            "avatars/users/other/x.jpg",
            owner_kind="user",
            owner_id="me",
        )
        is None
    )


def test_authorize_returns_none_for_legacy_external_url():
    assert (
        avatar_object_path_authorized(
            "https://lh3.googleusercontent.com/a/photo",
            owner_kind="user",
            owner_id="me",
        )
        is None
    )
