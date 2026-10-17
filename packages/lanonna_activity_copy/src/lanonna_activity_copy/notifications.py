"""Notification vocabulary shared by the API (publish) and worker (deliver).

The API publishes a **structured** notification: ``kind`` + actor uid +
``params`` (display values such as the event title). It never writes copy.

- **Inbox** (``notifications`` rows): the worker stores ``notification_kind``
  and ``params``; the app renders the sentence from ARB
  (``InboxNotificationKind`` in ``apps/mobile/lib/features/account/domain/``).
- **Push**: the OS shows FCM ``notification`` payloads itself while the app is
  in the background or closed, without running app code, so the push text is
  rendered here, server-side, from :func:`push_copy`. The product is English
  only (FR-SET-002). Supporting another language means storing the user's
  locale and choosing the copy per recipient in :func:`push_copy`; the payloads
  are already structured, so nothing else changes.

``title`` / ``body`` stored on the inbox row are the same English push copy,
kept for logs and for rows written before ``notification_kind`` existed.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any

from lanonna_activity_copy import params as p


class NotificationType(StrEnum):
    """Inbox icon category (``notifications.notification_type``, migration 036)."""

    PHOTO = "photo"
    EVENT = "event"
    REGISTRY = "registry"
    FUN = "fun"
    COMMENT = "comment"
    SQUISH = "squish"
    DIGEST = "digest"
    GENERIC = "generic"


class NotificationKind(StrEnum):
    """What happened (``notifications.notification_kind``, migration 038)."""

    PHOTO_SHARED = "photo_shared"
    PHOTO_SQUISHED = "photo_squished"
    PHOTO_COMMENTED = "photo_commented"
    EVENT_CREATED = "event_created"
    EVENT_RSVP = "event_rsvp"
    EVENT_COMMENTED = "event_commented"
    REGISTRY_PURCHASED = "registry_purchased"
    REGISTRY_BUYING = "registry_buying"
    INVITE_ACCEPTED = "invite_accepted"
    BABY_ARRIVED = "baby_arrived"
    # Push only; never stored in the inbox.
    WEEKLY_DIGEST = "weekly_digest"


NOTIFICATION_TYPE_BY_KIND: dict[NotificationKind, NotificationType] = {
    NotificationKind.PHOTO_SHARED: NotificationType.PHOTO,
    NotificationKind.PHOTO_SQUISHED: NotificationType.SQUISH,
    NotificationKind.PHOTO_COMMENTED: NotificationType.COMMENT,
    NotificationKind.EVENT_CREATED: NotificationType.EVENT,
    NotificationKind.EVENT_RSVP: NotificationType.EVENT,
    NotificationKind.EVENT_COMMENTED: NotificationType.COMMENT,
    NotificationKind.REGISTRY_PURCHASED: NotificationType.REGISTRY,
    NotificationKind.REGISTRY_BUYING: NotificationType.REGISTRY,
    NotificationKind.INVITE_ACCEPTED: NotificationType.GENERIC,
    NotificationKind.BABY_ARRIVED: NotificationType.GENERIC,
    NotificationKind.WEEKLY_DIGEST: NotificationType.DIGEST,
}

ACTOR_FALLBACK = "Someone"
BABY_FALLBACK = "your baby"

_RSVP_SENTENCES = {
    "going": '{who} is going to "{event}"',
    "maybe": '{who} might go to "{event}"',
    "cant_go": '{who} can\'t make it to "{event}"',
}


def notification_kind_from_payload(raw: Any) -> NotificationKind | None:
    try:
        return NotificationKind(str(raw))
    except ValueError:
        return None


def _text(params: dict[str, Any], key: str, fallback: str) -> str:
    value = str(params.get(key) or "").strip()
    return value or fallback


def push_copy(
    kind: NotificationKind,
    params: dict[str, Any],
    *,
    actor: str | None,
) -> tuple[str, str]:
    """English ``(title, body)`` for a push (and the inbox row's diagnostic text)."""
    who = (actor or "").strip() or ACTOR_FALLBACK
    event = _text(params, p.EVENT_TITLE, "an event")
    item = _text(params, p.ITEM_NAME, "an item")
    baby = _text(params, p.BABY_NAME, BABY_FALLBACK)
    match kind:
        case NotificationKind.PHOTO_SHARED:
            return "New photo", f"{who} shared a new photo"
        case NotificationKind.PHOTO_SQUISHED:
            return "New squish", f"{who} squished your photo"
        case NotificationKind.PHOTO_COMMENTED:
            return "New comment", f"{who} commented on your photo"
        case NotificationKind.EVENT_CREATED:
            return "New event", f'{who} added "{event}" to the calendar'
        case NotificationKind.EVENT_RSVP:
            sentence = _RSVP_SENTENCES.get(
                str(params.get(p.RSVP_STATUS)), '{who} replied to "{event}"'
            )
            return "New RSVP", sentence.format(who=who, event=event)
        case NotificationKind.EVENT_COMMENTED:
            return "New comment", f'{who} commented on "{event}"'
        case NotificationKind.REGISTRY_PURCHASED:
            return "Registry update", f'{who} marked "{item}" as purchased'
        case NotificationKind.REGISTRY_BUYING:
            return "Registry update", f'{who} is buying "{item}"'
        case NotificationKind.INVITE_ACCEPTED:
            return "Invite accepted", f"{who} joined {baby}"
        case NotificationKind.BABY_ARRIVED:
            return "Baby has arrived!", f"{baby} has arrived! See the announcement."
        case NotificationKind.WEEKLY_DIGEST:
            count = int(params.get(p.UNREAD_COUNT) or 0)
            noun = "update" if count == 1 else "updates"
            return "Your weekly update", f"You have {count} unread {noun} from La Nonna"
    raise ValueError(f"no push copy for {kind!r}")
