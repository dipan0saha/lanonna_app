"""Real Postgres for repository SQL that mocked unit tests cannot catch."""

from __future__ import annotations

from pathlib import Path

import psycopg
import pytest

_MIGRATIONS = Path(__file__).resolve().parents[4] / "infra" / "db" / "migrations"
_DB_NAME = "lanonna_pytest"
_PASSWORD = "postgres"


def _admin_conn() -> psycopg.Connection:
    return psycopg.connect(
        host="127.0.0.1",
        port=5432,
        user="postgres",
        password=_PASSWORD,
        dbname="postgres",
        autocommit=True,
    )


@pytest.fixture(scope="session")
def postgres_database() -> str:
    admin = _admin_conn()
    admin.execute(f'DROP DATABASE IF EXISTS "{_DB_NAME}" WITH (FORCE)')
    admin.execute(f'CREATE DATABASE "{_DB_NAME}"')
    admin.close()
    conn = psycopg.connect(
        host="127.0.0.1",
        port=5432,
        user="postgres",
        password=_PASSWORD,
        dbname=_DB_NAME,
    )
    # ClientCursor uses the simple query protocol so a migration file can
    # contain more than one statement, same as a psql script.
    for path in sorted(_MIGRATIONS.glob("*.sql")):
        with psycopg.ClientCursor(conn) as cur:
            cur.execute(path.read_text())
    conn.commit()
    conn.close()
    return _DB_NAME


@pytest.fixture(autouse=True)
def _point_api_at_postgres(postgres_database: str):
    from lanonna_api.config import settings
    from lanonna_api.db import close_pool, get_connection

    previous = (
        settings.db_host,
        settings.db_port,
        settings.db_user,
        settings.db_name,
        settings.db_password,
        settings.cloud_sql_connection_name,
    )
    settings.db_host = "127.0.0.1"
    settings.db_port = 5432
    settings.db_user = "postgres"
    settings.db_name = postgres_database
    settings.db_password = _PASSWORD
    settings.cloud_sql_connection_name = ""
    # The pool is bound to the settings it was opened with.
    close_pool()
    with get_connection() as conn:
        conn.execute(
            """
            TRUNCATE TABLE
                app_users,
                system_announcements
            RESTART IDENTITY CASCADE
            """
        )
    yield
    close_pool()
    (
        settings.db_host,
        settings.db_port,
        settings.db_user,
        settings.db_name,
        settings.db_password,
        settings.cloud_sql_connection_name,
    ) = previous
