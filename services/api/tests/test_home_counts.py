import uuid
from unittest.mock import MagicMock, patch

from lanonna_api.repositories.home_counts import count_photos_for_baby


def test_count_photos_for_baby_does_not_filter_deleted_at():
    baby_id = uuid.uuid4()
    mock_conn = MagicMock()
    mock_conn.execute.return_value.fetchone.return_value = {"count": 2}

    with patch("lanonna_api.repositories.home_counts.get_connection") as get_conn:
        get_conn.return_value.__enter__.return_value = mock_conn
        result = count_photos_for_baby(baby_id)

    assert result == 2
    sql = mock_conn.execute.call_args[0][0]
    assert "deleted_at" not in sql.lower()
    assert "baby_profile_id" in sql
