from unittest.mock import MagicMock, patch

from lanonna_worker.event_cover_cleanup import purge_stale_unreferenced_event_covers


def test_purge_stale_event_covers_deletes_storage():
    row = {"display_path": "babies/x/display.jpg", "thumb_path": "babies/x/thumb.jpg"}
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = [row]
    ctx = MagicMock()
    ctx.__enter__.return_value = conn

    with (
        patch("lanonna_worker.event_cover_cleanup.get_connection", return_value=ctx),
        patch(
            "lanonna_worker.event_cover_cleanup.delete_photo_paths",
            return_value=2,
        ) as delete_paths,
    ):
        count = purge_stale_unreferenced_event_covers(24)

    assert count == 1
    delete_paths.assert_called_once_with(row["display_path"], row["thumb_path"])
