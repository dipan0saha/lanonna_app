"""Shared activity and notification vocabulary for the La Nonna API and worker.

Server code records *what happened* (a type, the actor, display params); the
app owns user-facing copy (ARB). See ``activity.py`` and ``notifications.py``.
"""

from lanonna_activity_copy.activity import (
    ACTOR_HIDDEN_EVENT_TYPES,
    GALLERY_ACTIVITY_EVENT_TYPES,
    ActivityEventType,
    activity_summary,
    caption_params,
)
from lanonna_activity_copy.notifications import (
    NOTIFICATION_TYPE_BY_KIND,
    NotificationKind,
    NotificationType,
    notification_kind_from_payload,
    push_copy,
)

__all__ = [
    "ACTOR_HIDDEN_EVENT_TYPES",
    "GALLERY_ACTIVITY_EVENT_TYPES",
    "ActivityEventType",
    "activity_summary",
    "caption_params",
    "NOTIFICATION_TYPE_BY_KIND",
    "NotificationKind",
    "NotificationType",
    "notification_kind_from_payload",
    "push_copy",
]
