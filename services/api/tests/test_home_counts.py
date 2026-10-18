import re
import uuid
from unittest.mock import MagicMock, patch

from lanonna_api.repositories.home_counts import home_summary_counts


def _run_counts() -> tuple[str, MagicMock]:
    mock_conn = MagicMock()
    mock_conn.execute.return_value.fetchone.return_value = {"vote_count": 2}
    with patch("lanonna_api.repositories.home_counts.get_connection") as get_conn:
        get_conn.return_value.__enter__.return_value = mock_conn
        result = home_summary_counts(uuid.uuid4())
    assert result == {"vote_count": 2}
    return mock_conn.execute.call_args[0][0], mock_conn


def test_home_summary_counts_is_one_statement():
    _, conn = _run_counts()
    assert conn.execute.call_count == 1


def test_home_summary_counts_photo_flag_does_not_filter_deleted_at():
    sql, _ = _run_counts()
    photo_exists = re.search(r"EXISTS \(SELECT 1 FROM photos p\s+WHERE[^)]*\)", sql)
    assert photo_exists is not None
    assert "deleted_at" not in photo_exists.group(0)


def test_home_summary_counts_votes_count_active_participants_only():
    sql, _ = _run_counts()
    # gender totals and the top birth date guess both join active participants
    assert sql.count("JOIN baby_memberships membership") == 2
