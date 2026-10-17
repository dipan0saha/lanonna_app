from contextlib import contextmanager
from unittest.mock import MagicMock, patch

from lanonna_worker import notifications


def _conn(rows):
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = rows
    return conn


def test_weekly_digest_reads_counts_and_tokens_with_the_candidates():
    rows = [
        {"firebase_uid": "u1", "unread_count": 3, "fcm_tokens": ["t1"]},
        {"firebase_uid": "u2", "unread_count": 1, "fcm_tokens": ["t2", "t3"]},
    ]
    conn = _conn(rows)

    @contextmanager
    def fake_connection():
        yield conn

    with (
        patch.object(notifications, "get_connection", fake_connection),
        patch.object(notifications, "try_claim_delivery", return_value=True),
        patch.object(notifications, "_send_push") as send,
    ):
        notifications.process_weekly_notification_digest(pubsub_message_id="m1")

    sql = [c.args[0] for c in conn.execute.call_args_list]
    selects = [q for q in sql if "SELECT" in q]
    # One candidate query (counts and tokens joined in): no per-user COUNT or
    # device-token query, and one bookkeeping UPDATE for the whole run.
    assert len(selects) == 1
    assert "unread_count" in selects[0] and "fcm_tokens" in selects[0]
    assert [c.kwargs["tokens"] for c in send.call_args_list] == [["t1"], ["t2", "t3"]]
    assert "3 unread updates" in send.call_args_list[0].kwargs["body"]
    assert "1 unread update " in send.call_args_list[1].kwargs["body"]
    updates = [c for c in conn.execute.call_args_list if "last_weekly_digest_at = now()" in c.args[0]]
    assert len(updates) == 1
    assert updates[0].args[1] == (["u1", "u2"],)
