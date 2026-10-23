"""Avatar storage references sent by the app (#415).

Avatars are the only fields where the client names a storage object. Every
other photo field (event covers, announcement photos, gallery, tags) takes a
photo id that the API looks up under the baby. An avatar must name an object
directly under its owner's upload prefix, the same prefix
``/v1/uploads/display/signed-url`` mints into (``storage.py``), so nobody can
point their avatar at another account's object or at an outside URL.
"""

from __future__ import annotations

import uuid
from urllib.parse import unquote, urlparse

from lanonna_api.config import settings
from lanonna_api.domain.errors import ErrorCode, InvalidInputError

INVALID_AVATAR_REFERENCE = "Choose the photo again from this app."


def user_avatar_prefix(firebase_uid: str) -> str:
    return f"avatars/users/{firebase_uid}/"


def baby_avatar_prefix(baby_profile_id: uuid.UUID) -> str:
    return f"avatars/babies/{baby_profile_id}/"


def display_object_path(value: str | None) -> str | None:
    """The display-bucket object a stored or sent avatar names, else ``None``.

    Accepts a bare object path or an https URL into our display bucket (a
    signed or legacy public URL; the query string is ignored). Never raises,
    so reads can call it on any stored row.
    """
    s = (value or "").strip()
    if not s:
        return None
    if "://" in s:
        parsed = urlparse(s)
        if parsed.scheme != "https":
            return None
        bucket = settings.display_bucket
        raw = unquote(parsed.path).lstrip("/")
        if parsed.netloc == "storage.googleapis.com" and raw.startswith(f"{bucket}/"):
            s = raw[len(bucket) + 1 :]
        elif parsed.netloc == f"{bucket}.storage.googleapis.com":
            s = raw
        else:
            return None
    if s.startswith("/") or "\\" in s:
        return None
    if any(part in ("", ".", "..") for part in s.split("/")):
        return None
    return s


def owned_avatar_path(value: str | None, prefix: str) -> str | None:
    """The object path when it sits directly under [prefix] (as minted)."""
    path = display_object_path(value)
    if path is None or not path.startswith(prefix):
        return None
    name = path[len(prefix) :]
    return path if name and "/" not in name else None


def normalize_avatar_for_storage(value: str | None, prefix: str) -> str | None:
    """The value to persist: ``None`` clears, else the owned object path.

    Raises ``invalid_storage_reference`` (400) for anything else: another
    account's object, a path outside the avatar prefixes, or any outside URL.
    """
    if value is None or not value.strip():
        return None
    path = owned_avatar_path(value, prefix)
    if path is None:
        raise InvalidInputError(ErrorCode.INVALID_STORAGE_REFERENCE, INVALID_AVATAR_REFERENCE)
    return path
