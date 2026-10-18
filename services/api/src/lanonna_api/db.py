"""Postgres access for every repository: one connection pool per process.

``get_connection()`` borrows a pooled connection and keeps the original
contract: the block commits on success and rolls back on an exception. The
pool is opened in the FastAPI lifespan (``open_pool``) so the first request
after a cold start does not pay for connecting, and closed on shutdown. Code
that runs outside the app (tests, scripts) opens it lazily on first use.

``read_scope()`` lets a read-only aggregate (home summary, photo detail, …)
run every repository call on one pooled connection in one read-only
transaction instead of borrowing a connection per query. The connection is
borrowed by the first repository call inside the scope (none if nothing
queries) and returned when the scope ends. A write inside the scope fails
loudly (``READ ONLY`` transaction).
"""

from __future__ import annotations

import threading
from contextlib import ExitStack, contextmanager
from contextvars import ContextVar
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from lanonna_api.config import settings

_pool: ConnectionPool | None = None
_pool_lock = threading.Lock()


class _ReadScope:
    def __init__(self) -> None:
        self.stack = ExitStack()
        self.conn: psycopg.Connection[Any] | None = None


_read_scope: ContextVar[_ReadScope | None] = ContextVar("lanonna_read_scope", default=None)


def _connect_kwargs() -> dict[str, Any]:
    if settings.cloud_sql_connection_name:
        host = f"/cloudsql/{settings.cloud_sql_connection_name}"
        return {
            "host": host,
            "user": settings.db_user,
            "dbname": settings.db_name,
            "password": settings.db_password,
        }
    return {
        "host": settings.db_host,
        "port": settings.db_port,
        "user": settings.db_user,
        "dbname": settings.db_name,
        "password": settings.db_password,
    }


@contextmanager
def _read_only_transaction(pool: ConnectionPool) -> Iterator[psycopg.Connection[Any]]:
    """Borrow a connection for ``read_scope``: one read-only transaction.

    The transaction is ended and the connection's ``read_only`` flag cleared
    here, before the pool takes it back, so a returned connection is always
    in its default state (no pool reset callback, which would return
    connections asynchronously).
    """
    with pool.connection() as conn:
        conn.read_only = True
        try:
            yield conn
            conn.commit()
        except BaseException:
            if not conn.closed:
                conn.rollback()
            raise
        finally:
            if not conn.closed:
                conn.read_only = None


def _require_configured() -> None:
    if not settings.db_password:
        raise RuntimeError("Database is not configured (missing DB_PASSWORD).")


def open_pool() -> ConnectionPool:
    """Create and open the process pool (idempotent).

    Opening does not wait for connections: the pool fills in the background
    and retries, so a slow or briefly unavailable database cannot fail
    startup. Requests wait up to ``db_pool_timeout_seconds`` for a connection.
    """
    global _pool
    _require_configured()
    with _pool_lock:
        if _pool is None:
            _pool = ConnectionPool(
                kwargs={**_connect_kwargs(), "row_factory": dict_row},
                min_size=settings.db_pool_min_size,
                max_size=settings.db_pool_max_size,
                timeout=settings.db_pool_timeout_seconds,
                max_idle=settings.db_pool_max_idle_seconds,
                check=ConnectionPool.check_connection,
                name="lanonna-api",
                open=True,
            )
        return _pool


def close_pool() -> None:
    """Close the process pool (lifespan shutdown, tests that change settings)."""
    global _pool
    with _pool_lock:
        pool, _pool = _pool, None
    if pool is not None:
        pool.close()


def _pool_or_open() -> ConnectionPool:
    _require_configured()
    return _pool or open_pool()


@contextmanager
def get_connection() -> Iterator[psycopg.Connection[Any]]:
    scope = _read_scope.get()
    if scope is not None:
        # Inside read_scope: share its connection; the scope owns the transaction.
        if scope.conn is None:
            scope.conn = scope.stack.enter_context(_read_only_transaction(_pool_or_open()))
        yield scope.conn
        return
    # Commits when the block succeeds, rolls back on an exception.
    with _pool_or_open().connection() as conn:
        yield conn


@contextmanager
def read_scope() -> Iterator[None]:
    """Run every repository call in the block on one read-only pooled connection."""
    if _read_scope.get() is not None:
        yield
        return
    scope = _ReadScope()
    token = _read_scope.set(scope)
    try:
        # Exiting the stack returns the connection: commit, or rollback on error.
        with scope.stack:
            yield
    finally:
        _read_scope.reset(token)
