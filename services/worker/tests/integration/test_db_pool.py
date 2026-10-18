"""Worker pool lifecycle against real Postgres."""

from __future__ import annotations

import pytest

from lanonna_worker import db
from lanonna_worker.config import settings


def test_pool_is_idempotent_reused_and_closed():
    pool = db.open_pool()
    assert db.open_pool() is pool
    assert pool.max_size == settings.db_pool_max_size == 2
    pids = set()
    for _ in range(10):
        with db.get_connection() as conn:
            pids.add(conn.execute("SELECT pg_backend_pid() AS p").fetchone()["p"])
    assert len(pids) <= 2
    db.close_pool()
    assert pool.closed and db._pool is None


def test_rollback_on_error_commit_on_success():
    with db.get_connection() as conn:
        conn.execute("CREATE TABLE IF NOT EXISTS worker_probe (v int)")
        conn.execute("TRUNCATE worker_probe")
        conn.execute("INSERT INTO worker_probe VALUES (1)")
    with pytest.raises(RuntimeError):
        with db.get_connection() as conn:
            conn.execute("INSERT INTO worker_probe VALUES (2)")
            raise RuntimeError("boom")
    with db.get_connection() as conn:
        rows = conn.execute("SELECT v FROM worker_probe").fetchall()
        conn.execute("DROP TABLE worker_probe")
    assert [r["v"] for r in rows] == [1]


def test_missing_password_still_raises_database_not_configured(monkeypatch):
    db.close_pool()
    monkeypatch.setattr(settings, "db_password", "")
    with pytest.raises(db.DatabaseNotConfiguredError):
        with db.get_connection():
            pass
