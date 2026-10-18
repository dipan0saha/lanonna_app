"""Pool and read_scope lifecycle against real Postgres."""

from __future__ import annotations

import psycopg
import pytest

from lanonna_api import db
from lanonna_api.config import settings


def _backend_pid(conn) -> int:
    return conn.execute("SELECT pg_backend_pid() AS pid").fetchone()["pid"]


def test_open_pool_is_idempotent_and_close_releases_it():
    pool = db.open_pool()
    assert db.open_pool() is pool
    assert pool.max_size == settings.db_pool_max_size
    assert pool.min_size == settings.db_pool_min_size
    db.close_pool()
    assert pool.closed
    assert db._pool is None
    db.close_pool()  # closing twice is harmless


def test_get_connection_reuses_pooled_connections():
    pool = db.open_pool()
    pids = set()
    for _ in range(10):
        with db.get_connection() as conn:
            pids.add(_backend_pid(conn))
    # Sequential calls cycle through the few pooled connections instead of
    # opening a new one each time.
    assert len(pids) <= 2
    assert pool.get_stats()["connections_num"] <= 2


def test_get_connection_commits_on_success_and_rolls_back_on_error():
    with db.get_connection() as conn:
        conn.execute("CREATE TABLE IF NOT EXISTS pool_probe (v int)")
        conn.execute("TRUNCATE pool_probe")
    with db.get_connection() as conn:
        conn.execute("INSERT INTO pool_probe VALUES (1)")
    with pytest.raises(RuntimeError):
        with db.get_connection() as conn:
            conn.execute("INSERT INTO pool_probe VALUES (2)")
            raise RuntimeError("boom")
    with db.get_connection() as conn:
        rows = conn.execute("SELECT v FROM pool_probe ORDER BY v").fetchall()
        conn.execute("DROP TABLE pool_probe")
    assert [r["v"] for r in rows] == [1]


def test_get_connection_without_password_raises(monkeypatch):
    db.close_pool()
    monkeypatch.setattr(settings, "db_password", "")
    with pytest.raises(RuntimeError, match="not configured"):
        with db.get_connection():
            pass


def test_read_scope_borrows_lazily(monkeypatch):
    db.close_pool()
    monkeypatch.setattr(settings, "db_password", "")
    # Nothing queries, so nothing is borrowed (and no DB is needed).
    with db.read_scope():
        pass


def test_read_scope_shares_one_read_only_connection_then_resets_it():
    db.open_pool()
    with db.read_scope():
        with db.get_connection() as a:
            pid_a = _backend_pid(a)
        with db.get_connection() as b:
            pid_b = _backend_pid(b)
            assert b.read_only is True
            with db.read_scope():  # nested scopes join the outer one
                with db.get_connection() as c:
                    assert c is b
    assert pid_a == pid_b
    with db.get_connection() as conn:
        assert not conn.read_only
        conn.execute("CREATE TEMP TABLE writable (v int)")


def test_read_scope_rejects_writes():
    with pytest.raises(psycopg.errors.ReadOnlySqlTransaction):
        with db.read_scope():
            with db.get_connection() as conn:
                conn.execute("CREATE TABLE should_not_exist (v int)")
    with db.get_connection() as conn:
        assert not conn.read_only
        exists = conn.execute("SELECT to_regclass('should_not_exist') AS t").fetchone()["t"]
    assert exists is None


def test_read_scope_returns_connection_after_an_error():
    db.open_pool()
    with pytest.raises(ValueError):
        with db.read_scope():
            with db.get_connection() as conn:
                conn.execute("SELECT 1")
                scoped = conn
            raise ValueError("domain error")
    # Rolled back, reset and handed back to the pool.
    assert scoped.info.transaction_status == psycopg.pq.TransactionStatus.IDLE
    assert not scoped.read_only
    assert db._read_scope.get() is None
