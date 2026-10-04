from unittest.mock import MagicMock, patch

from lanonna_worker.invite_cleanup import expire_stale_pending_invitations


def test_expire_stale_pending_invitations_returns_count():
    conn = MagicMock()
    conn.execute.return_value = MagicMock(rowcount=3)
    with patch("lanonna_worker.invite_cleanup.get_connection") as gc:
        gc.return_value.__enter__.return_value = conn
        count = expire_stale_pending_invitations()
    assert count == 3
