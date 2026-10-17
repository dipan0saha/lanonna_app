"""Shared feed vocabulary (lanonna_activity_copy) and the app's enums stay in sync.

The app renders activity rows and inbox notifications from ARB by type / kind
and reads display values by param key; anything it does not know falls back to
the server's English diagnostic copy. Migration 038's CHECK constraint must
list the same stored kinds.
"""

import re
from pathlib import Path

from lanonna_activity_copy import ActivityEventType, NotificationKind
from lanonna_activity_copy import params as feed_params

from lanonna_api.schemas.invitations import InviteRowStatus

_REPO = Path(__file__).resolve().parents[3]
_MOBILE = _REPO / "apps/mobile/lib"


def _dart_enum_values(relative: str, enum_name: str) -> set[str]:
    text = (_MOBILE / relative).read_text(encoding="utf-8")
    body = text[text.index(f"enum {enum_name} {{") : text.index(f"const {enum_name}(")]
    return set(re.findall(r"^\s+\w+\('([a-z_]+)'\)[,;]", body, re.MULTILINE))


def test_activity_event_types_match_app_enum():
    assert _dart_enum_values(
        "core/domain/activity_event_type.dart", "ActivityEventType"
    ) == {t.value for t in ActivityEventType}


def test_inbox_kinds_match_app_enum_and_migration_check():
    stored = {k.value for k in NotificationKind} - {NotificationKind.WEEKLY_DIGEST.value}
    assert _dart_enum_values(
        "features/account/domain/inbox_notification_kind.dart", "InboxNotificationKind"
    ) == stored
    migration = (
        _REPO / "infra/db/migrations/038_structured_notification_activity_params.sql"
    ).read_text(encoding="utf-8")
    check = migration[migration.index("notification_kind IN (") : migration.index("));")]
    assert set(re.findall(r"'([a-z_]+)'", check)) == stored


def test_param_keys_match_app_constants():
    text = (_MOBILE / "core/domain/feed_params.dart").read_text(encoding="utf-8")
    dart = set(re.findall(r"static const \w+ = '([a-z_]+)';", text))
    python = {
        value
        for name, value in vars(feed_params).items()
        if name.isupper() and isinstance(value, str)
    }
    # unread_count is push-only (weekly digest), never rendered in the app.
    assert dart == python - {feed_params.UNREAD_COUNT}


def test_invite_row_statuses_match_app_enum():
    assert _dart_enum_values(
        "features/invitations/domain/invitation_status.dart", "InviteRowStatus"
    ) == {s.value for s in InviteRowStatus}
