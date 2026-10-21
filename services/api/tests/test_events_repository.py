import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from lanonna_api.repositories.events import LIST_EVENTS_MAX_ROWS, list_events


def test_list_events_unscoped_includes_limit():
    baby_id = uuid.uuid4()
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = []
    with patch("lanonna_api.repositories.events.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        list_events(baby_id)
    sql = conn.execute.call_args[0][0]
    params = conn.execute.call_args[0][1]
    assert "LIMIT" in sql
    assert LIST_EVENTS_MAX_ROWS in params


def test_list_events_past_only_orders_desc_with_limit():
    baby_id = uuid.uuid4()
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = []
    with patch("lanonna_api.repositories.events.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        list_events(
            baby_id,
            past_only=True,
            now=datetime(2026, 1, 1, tzinfo=timezone.utc),
            limit=30,
        )
    sql = conn.execute.call_args[0][0]
    params = conn.execute.call_args[0][1]
    assert "starts_at <" in sql
    assert "ORDER BY e.starts_at DESC" in sql
    assert 30 in params


def test_list_events_upcoming_only_has_no_limit():
    baby_id = uuid.uuid4()
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = []
    with patch("lanonna_api.repositories.events.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        list_events(
            baby_id,
            upcoming_only=True,
            now=datetime(2026, 1, 1, tzinfo=timezone.utc),
        )
    sql = conn.execute.call_args[0][0]
    assert "LIMIT" not in sql
