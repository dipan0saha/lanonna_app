"""Validate client-supplied display-bucket object paths and owned avatars."""

from __future__ import annotations

import re
import uuid
from typing import Literal
from urllib.parse import unquote, urlparse

from lanonna_api.config import settings
from lanonna_api.domain.errors import ErrorCode, UnprocessableInputError

INVALID_STORAGE_REFERENCE = (
    "Use a photo uploaded from this app for your profile or baby avatar."
)

_AVATAR_USER_PREFIX = "avatars/users/"
_AVATAR_BABY_PREFIX = "avatars/babies/"
_DISPLAY_PREFIX = "display/"
_ALLOWED_OBJECT_PREFIXES = (_AVATAR_USER_PREFIX, _AVATAR_BABY_PREFIX, _DISPLAY_PREFIX)

# Firebase uid and UUID string forms used in object paths.
_UID_SEGMENT = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
_UUID_SEGMENT = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def _reject_storage_reference(message: str = INVALID_STORAGE_REFERENCE) -> None:
    raise UnprocessableInputError(ErrorCode.INVALID_STORAGE_REFERENCE, message)


def _normalize_object_path(path: str) -> str:
    cleaned = path.strip().lstrip("/")
    if not cleaned or ".." in cleaned or "\\" in cleaned:
        _reject_storage_reference()
    if not cleaned.startswith(_ALLOWED_OBJECT_PREFIXES):
        _reject_storage_reference()
    return cleaned


def display_object_path_from_client_value(value: str) -> str | None:
    """Parse a stored object path or legacy public GCS URL for our display bucket."""
    s = value.strip()
    if not s:
        return None
    if s.startswith(_ALLOWED_OBJECT_PREFIXES):
        return _normalize_object_path(s)

    if not (s.startswith("http://") or s.startswith("https://")):
        return None

    bucket = settings.display_bucket
    parsed = urlparse(s)
    path = unquote(parsed.path.lstrip("/"))

    if parsed.netloc == "storage.googleapis.com":
        if path.startswith(f"{bucket}/"):
            return _normalize_object_path(path[len(bucket) + 1 :])
        parts = path.split("/", 1)
        if len(parts) == 2 and parts[0] == bucket:
            return _normalize_object_path(parts[1])

    if parsed.netloc == f"{bucket}.storage.googleapis.com":
        return _normalize_object_path(path)

    return None


def user_avatar_object_prefix(firebase_uid: str) -> str:
    if not _UID_SEGMENT.match(firebase_uid):
        _reject_storage_reference()
    return f"{_AVATAR_USER_PREFIX}{firebase_uid}/"


def baby_avatar_object_prefix(baby_profile_id: uuid.UUID) -> str:
    baby_id = str(baby_profile_id)
    if not _UUID_SEGMENT.match(baby_id):
        _reject_storage_reference()
    return f"{_AVATAR_BABY_PREFIX}{baby_id}/"


def normalize_owned_avatar_for_storage(
    value: str | None,
    *,
    owner_kind: Literal["user", "baby"],
    owner_id: str,
) -> str | None:
    """Persist only object paths under the owner's avatar upload prefix."""
    if value is None:
        return None
    s = value.strip()
    if not s:
        return None

    if s.startswith("http://"):
        _reject_storage_reference()

    path = display_object_path_from_client_value(s)
    if path is None:
        _reject_storage_reference()

    expected = (
        user_avatar_object_prefix(owner_id)
        if owner_kind == "user"
        else baby_avatar_object_prefix(uuid.UUID(owner_id))
    )
    if not path.startswith(expected):
        _reject_storage_reference()
    return path


def avatar_object_path_authorized(
    stored: str | None,
    *,
    owner_kind: Literal["user", "baby"],
    owner_id: str,
) -> str | None:
    """Return the object path only if [stored] is owned by [owner_id]; else None."""
    if not stored or not str(stored).strip():
        return None
    path = display_object_path_from_client_value(str(stored).strip())
    if path is None:
        return None
    expected = (
        user_avatar_object_prefix(owner_id)
        if owner_kind == "user"
        else baby_avatar_object_prefix(uuid.UUID(owner_id))
    )
    if not path.startswith(expected):
        return None
    return path
