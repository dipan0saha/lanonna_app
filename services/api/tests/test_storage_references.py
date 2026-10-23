import uuid

import pytest

from lanonna_api.config import settings
from lanonna_api.domain.errors import ErrorCode, InvalidInputError
from lanonna_api.domain.storage_references import (
    baby_avatar_prefix,
    display_object_path,
    normalize_avatar_for_storage,
    owned_avatar_path,
    user_avatar_prefix,
)

BUCKET = settings.display_bucket
OWN = "avatars/users/u1/a.webp"


@pytest.mark.parametrize(
    "value",
    [
        OWN,
        f"https://storage.googleapis.com/{BUCKET}/{OWN}",
        f"https://storage.googleapis.com/{BUCKET}/{OWN}?X-Goog-Signature=abc",
        f"https://{BUCKET}.storage.googleapis.com/{OWN}",
    ],
)
def test_display_object_path_reads_paths_and_our_bucket_urls(value):
    assert display_object_path(value) == OWN


@pytest.mark.parametrize(
    "value",
    [
        None,
        "",
        "  ",
        f"http://storage.googleapis.com/{BUCKET}/{OWN}",
        f"https://storage.googleapis.com/other-bucket/{OWN}",
        "https://example.com/avatars/users/u1/a.webp",
        "/avatars/users/u1/a.webp",
        "avatars/users/u1/../victim/a.webp",
        "avatars/users//a.webp",
        "avatars\\users\\u1\\a.webp",
    ],
)
def test_display_object_path_is_none_for_anything_else_and_never_raises(value):
    assert display_object_path(value) is None


def test_owned_path_must_sit_directly_under_the_prefix():
    prefix = user_avatar_prefix("u1")
    assert owned_avatar_path(OWN, prefix) == OWN
    assert owned_avatar_path("avatars/users/u1/nested/a.webp", prefix) is None
    assert owned_avatar_path("avatars/users/u1/", prefix) is None
    assert owned_avatar_path("avatars/users/u10/a.webp", prefix) is None
    assert owned_avatar_path("avatars/users/victim/a.webp", prefix) is None


@pytest.mark.parametrize(
    "value",
    [
        "avatars/users/victim/a.webp",
        f"https://storage.googleapis.com/{BUCKET}/avatars/users/victim/a.webp",
        "https://example.com/track.png",
        "http://example.com/a.png",
        "smoke/a.webp",
        "display/a.webp",
        f"avatars/babies/{uuid.uuid4()}/a.webp",
    ],
)
def test_normalize_rejects_everything_but_the_owners_object(value):
    with pytest.raises(InvalidInputError) as exc:
        normalize_avatar_for_storage(value, user_avatar_prefix("u1"))
    assert exc.value.code == ErrorCode.INVALID_STORAGE_REFERENCE
    assert exc.value.status_code == 400


def test_normalize_clears_and_stores_the_bare_path():
    prefix = user_avatar_prefix("u1")
    assert normalize_avatar_for_storage(None, prefix) is None
    assert normalize_avatar_for_storage("  ", prefix) is None
    assert (
        normalize_avatar_for_storage(f"https://storage.googleapis.com/{BUCKET}/{OWN}?sig=1", prefix)
        == OWN
    )


def test_baby_prefix_is_per_baby():
    baby_id = uuid.uuid4()
    path = f"{baby_avatar_prefix(baby_id)}pic.jpg"
    assert normalize_avatar_for_storage(path, baby_avatar_prefix(baby_id)) == path
    with pytest.raises(InvalidInputError):
        normalize_avatar_for_storage(path, baby_avatar_prefix(uuid.uuid4()))
