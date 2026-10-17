from contextlib import contextmanager
from unittest.mock import MagicMock, patch

from lanonna_worker import notifications


def _conn(rows):
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = rows
    return conn


def test_weekly_digest_reads_unread_counts_with_the_candidates():
    rows = [
        {"firebase_uid": "u1", "unread_count": 3},
        {"firebase_uid": "u2", "unread_count": 1},
    ]
    conn = _conn(rows)

    @contextmanager
    def fake_connection():
        yield conn

    with (
        patch.object(notifications, "get_connection", fake_connection),
        patch.object(notifications, "try_claim_delivery", return_value=True),
        patch.object(notifications, "_list_fcm_tokens", return_value=["t"]),
        patch.object(notifications, "_send_multicast_and_prune_tokens") as send,
    ):
        notifications.process_weekly_notification_digest(pubsub_message_id="m1")

    sql = [c.args[0] for c in conn.execute.call_args_list]
    selects = [q for q in sql if "SELECT" in q]
    # One candidate query (counts joined in), never a COUNT query per user.
    assert len(selects) == 1 and "unread_count" in selects[0]
    assert send.call_count == 2
    updates = [q for q in sql if "last_weekly_digest_at = now()" in q]
    assert len(updates) == 2
