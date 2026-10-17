"""Display param keys shared by activity rows and notifications.

Values are plain strings captured when the event happened (``rsvp_status`` and
``gender`` are server enum values; the app shows their localized labels).
The app reads the same keys (``apps/mobile/lib/core/domain/feed_params.dart``;
``test_feed_vocabulary_parity.py`` keeps them in sync). ``unread_count`` is
push-only (weekly digest).
"""

CAPTION = "caption"
ITEM_NAME = "item_name"
EVENT_TITLE = "event_title"
SUGGESTED_NAME = "suggested_name"
GENDER = "gender"
BABY_NAME = "baby_name"
RSVP_STATUS = "rsvp_status"
UNREAD_COUNT = "unread_count"
