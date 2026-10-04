#!/usr/bin/env python3
"""Apply SQL migrations in infra/db/migrations/ (lexicographic order).

Skips migrations already recorded in schema_migrations (filename stem = version).

Local dev (requires Cloud SQL Auth Proxy on 127.0.0.1:5432 or 5433):
  cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432
  DB_PASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev) \\
    python apply_migrations.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import psycopg

MIGRATIONS_DIR = Path(__file__).resolve().parent / "migrations"


def connect() -> psycopg.Connection:
    host = os.environ.get("DB_HOST", "127.0.0.1")
    port = int(os.environ.get("DB_PORT", "5432"))
    user = os.environ.get("DB_USER", "lanonna_app")
    dbname = os.environ.get("DB_NAME", "lanonna")
    password = os.environ.get("DB_PASSWORD")
    if not password:
        raise SystemExit("Set DB_PASSWORD (e.g. from Secret Manager).")
    return psycopg.connect(
        host=host,
        port=port,
        user=user,
        dbname=dbname,
        password=password,
    )


def _migration_version(path: Path) -> str:
    return path.stem


def _is_applied(conn: psycopg.Connection, version: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM schema_migrations WHERE version = %s",
        (version,),
    ).fetchone()
    return row is not None


def main() -> None:
    files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not files:
        print("No migrations found.", file=sys.stderr)
        sys.exit(1)
    with connect() as conn:
        for path in files:
            version = _migration_version(path)
            if _is_applied(conn, version):
                print(f"Skipping {path.name} (already applied)")
                continue
            sql = path.read_text()
            print(f"Applying {path.name}...")
            conn.execute(sql)
        conn.commit()
    print("Done.")


if __name__ == "__main__":
    main()
