from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row

from lanonna_api.config import settings


@contextmanager
def get_connection() -> Iterator[psycopg.Connection[Any]]:
    if not settings.db_password:
        raise RuntimeError("Database is not configured (missing DB_PASSWORD).")
    if settings.cloud_sql_connection_name:
        host = f"/cloudsql/{settings.cloud_sql_connection_name}"
        conn = psycopg.connect(
            host=host,
            user=settings.db_user,
            dbname=settings.db_name,
            password=settings.db_password,
            row_factory=dict_row,
        )
    else:
        conn = psycopg.connect(
            host=settings.db_host,
            port=settings.db_port,
            user=settings.db_user,
            dbname=settings.db_name,
            password=settings.db_password,
            row_factory=dict_row,
        )
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


