from unittest.mock import MagicMock

from lanonna_worker.notifications import _user_channel_enabled


def test_user_channel_enabled_missing_user():
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = None
    assert _user_channel_enabled(conn, "uid", "gallery") is False


def test_user_channel_disabled():
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = {"enabled": False}
    assert _user_channel_enabled(conn, "uid", "gallery") is False


def test_user_channel_unknown_passes():
    conn = MagicMock()
    assert _user_channel_enabled(conn, "uid", "unknown") is True
