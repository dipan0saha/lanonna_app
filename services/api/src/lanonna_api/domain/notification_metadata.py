"""Structured notification fields shared by API publish paths and inbox rows."""

from __future__ import annotations

from enum import StrEnum

from lanonna_api.domain.users_display import actor_display_name


class NotificationType(StrEnum):
    PHOTO = "photo"
    EVENT = "event"
    REGISTRY = "registry"
    FUN = "fun"
    COMMENT = "comment"
    SQUISH = "squish"
    DIGEST = "digest"
    GENERIC = "generic"


def actor_fields(actor_firebase_uid: str | None) -> dict[str, str | None]:
    if not actor_firebase_uid:
        return {"actor_firebase_uid": None, "actor_display_name": None}
    return {
        "actor_firebase_uid": actor_firebase_uid,
        "actor_display_name": actor_display_name(actor_firebase_uid),
    }
