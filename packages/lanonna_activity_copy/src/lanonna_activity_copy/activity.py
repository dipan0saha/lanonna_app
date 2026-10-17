"""Home activity feed vocabulary: event types and their display params.

An ``activity_events`` row is **structured**: ``event_type`` + actor uid +
``params`` (display values captured when the event happened, e.g. the item
name). The app renders the sentence from ARB (``ActivityEventType`` in
``apps/mobile/lib/core/domain/activity_event_type.dart``). People are not stored in ``params``: the
API resolves the actor's (and a removed member's) current display name at read
time, and returns ``null`` when they have none so the app shows its own
fallback.

``summary`` keeps an English sentence for logs and the owner data export only.
The app never shows it for a type it knows.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any

from lanonna_activity_copy import params as p


class ActivityEventType(StrEnum):
    PHOTO_SHARED = "photo_shared"
    PHOTO_SQUISH = "photo_squish"
    PHOTO_COMMENT = "photo_comment"
    REGISTRY_ITEM_ADDED = "registry_item_added"
    # An owner marked an item purchased (named in the feed).
    REGISTRY_PURCHASED = "registry_purchased"
    # A follower claimed an item; the feed keeps the buyer anonymous.
    REGISTRY_CLAIMED = "registry_claimed"
    EVENT_CREATED = "event_created"
    NAME_SUGGESTED = "name_suggested"
    GENDER_VOTE_CAST = "gender_vote_cast"
    BABY_ARRIVED = "baby_arrived"
    MEMBER_REMOVED = "member_removed"
    MEMBER_LEFT = "member_left"


GALLERY_ACTIVITY_EVENT_TYPES: frozenset[str] = frozenset(
    {ActivityEventType.PHOTO_SQUISH, ActivityEventType.PHOTO_COMMENT}
)

# Feed rows whose actor is never exposed (gift surprise).
ACTOR_HIDDEN_EVENT_TYPES: frozenset[str] = frozenset(
    {ActivityEventType.REGISTRY_CLAIMED}
)


def caption_params(caption: str | None) -> dict[str, str]:
    """Photo events carry the caption only when there is one."""
    text = (caption or "").strip()
    return {p.CAPTION: text} if text else {}


def _quoted_or(value: Any, fallback: str) -> str:
    text = str(value or "").strip()
    return f'"{text}"' if text else fallback


def activity_summary(
    event_type: str,
    params: dict[str, Any],
    *,
    actor: str = "Someone",
    target: str = "a member",
) -> str:
    """English diagnostic sentence stored in ``activity_events.summary``."""
    caption = _quoted_or(params.get(p.CAPTION), "a photo")
    item = _quoted_or(params.get(p.ITEM_NAME), "an item")
    match event_type:
        case ActivityEventType.PHOTO_SHARED:
            return f"{actor} shared {caption}"
        case ActivityEventType.PHOTO_SQUISH:
            return f"{actor} squished {caption}"
        case ActivityEventType.PHOTO_COMMENT:
            return f"{actor} commented on {caption}"
        case ActivityEventType.REGISTRY_ITEM_ADDED:
            return f"{actor} added {item} to the registry"
        case ActivityEventType.REGISTRY_PURCHASED:
            return f"{actor} marked {item} as purchased"
        case ActivityEventType.REGISTRY_CLAIMED:
            return f"Someone is buying {item}"
        case ActivityEventType.EVENT_CREATED:
            title = _quoted_or(params.get(p.EVENT_TITLE), "an event")
            return f"{actor} added {title} to the calendar"
        case ActivityEventType.NAME_SUGGESTED:
            name = _quoted_or(params.get(p.SUGGESTED_NAME), "a name")
            return f"{actor} suggested the name {name}"
        case ActivityEventType.GENDER_VOTE_CAST:
            return f"{actor} guessed {params.get(p.GENDER) or 'the gender'}"
        case ActivityEventType.BABY_ARRIVED:
            return f"{params.get(p.BABY_NAME) or 'The baby'} has arrived!"
        case ActivityEventType.MEMBER_REMOVED:
            return f"{actor} removed {target} from the family"
        case ActivityEventType.MEMBER_LEFT:
            return f"{actor} left the family"
    return f"{actor}: {event_type}"
