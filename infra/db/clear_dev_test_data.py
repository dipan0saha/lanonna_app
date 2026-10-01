#!/usr/bin/env python3
"""Remove baby-domain test data from dev Cloud SQL (local proxy).

Keeps `app_users` rows (Firebase accounts) unless you pass ``--delete-app-user``.

Typical owner retest (proxy on 127.0.0.1, default port 5432):

  export PGPASSWORD=$(gcloud secrets versions access latest \\
    --secret=db-lanonna-app-password --project=lanonna-dev)
  cd infra/db
  DB_PASSWORD="$PGPASSWORD" DB_PORT=5433 python clear_dev_test_data.py \\
    --email you@example.com --reset-onboarding

Use ``--dry-run`` to preview. GCS objects for deleted ``photos`` rows are not
removed automatically; paths are printed when ``--verbose``.
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

import psycopg
from psycopg.rows import dict_row

def _scalar(row: Any, index: int = 0) -> Any:
    if row is None:
        return None
    if isinstance(row, dict):
        return list(row.values())[index]
    return row[index]


BABY_CHILD_TABLES = (
    "activity_events",
    "name_suggestions",
    "registry_items",
    "events",
    "photos",
    "invitations",
    "baby_memberships",
)


def connect() -> psycopg.Connection:
    host = os.environ.get("DB_HOST", "127.0.0.1")
    port = int(os.environ.get("DB_PORT", "5432"))
    user = os.environ.get("DB_USER", "lanonna_app")
    dbname = os.environ.get("DB_NAME", "lanonna")
    password = os.environ.get("DB_PASSWORD")
    if not password:
        raise SystemExit("Set DB_PASSWORD (e.g. export PGPASSWORD=…).")
    return psycopg.connect(
        host=host,
        port=port,
        user=user,
        dbname=dbname,
        password=password,
        row_factory=dict_row,
    )


def _resolve_user(
    conn: psycopg.Connection,
    email: str | None,
    firebase_uid: str | None,
) -> dict[str, Any]:
    if firebase_uid:
        row = conn.execute(
            "SELECT firebase_uid, email FROM app_users WHERE firebase_uid = %s",
            (firebase_uid,),
        ).fetchone()
    elif email:
        row = conn.execute(
            "SELECT firebase_uid, email FROM app_users WHERE lower(email) = lower(%s)",
            (email.strip(),),
        ).fetchone()
    else:
        raise SystemExit("Provide --email or --firebase-uid (or --all-babies).")
    if row is None:
        raise SystemExit("No app_users row found for that identifier.")
    if isinstance(row, dict):
        return row
    return {"firebase_uid": row[0], "email": row[1]}


def _baby_ids_for_user(conn: psycopg.Connection, uid: str) -> list[str]:
    rows = conn.execute(
        """
        SELECT DISTINCT baby_profile_id::text
        FROM baby_memberships
        WHERE firebase_uid = %s
        """,
        (uid,),
    ).fetchall()
    return [_scalar(r) for r in rows]


def _all_baby_ids(conn: psycopg.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT id::text FROM baby_profiles WHERE deleted_at IS NULL"
    ).fetchall()
    return [_scalar(r) for r in rows]


def _photo_paths(conn: psycopg.Connection, baby_ids: list[str]) -> list[str]:
    if not baby_ids:
        return []
    rows = conn.execute(
        """
        SELECT display_path FROM photos
        WHERE baby_profile_id = ANY(%s::uuid[])
          AND display_path IS NOT NULL
        """,
        (baby_ids,),
    ).fetchall()
    return [_scalar(r) for r in rows]


def _delete_babies(conn: psycopg.Connection, baby_ids: list[str], dry_run: bool) -> None:
    if not baby_ids:
        print("No baby profiles to delete.")
        return

    print(f"Baby profile IDs ({len(baby_ids)}): {', '.join(baby_ids)}")

    for table in BABY_CHILD_TABLES:
        count = _scalar(
            conn.execute(
                f"""
            SELECT COUNT(*)::int FROM {table}
            WHERE baby_profile_id = ANY(%s::uuid[])
            """,
                (baby_ids,),
            ).fetchone()
        )
        print(f"  {table}: {count} row(s)")
        if not dry_run and count:
            conn.execute(
                f"DELETE FROM {table} WHERE baby_profile_id = ANY(%s::uuid[])",
                (baby_ids,),
            )

    count = _scalar(
        conn.execute(
            """
        SELECT COUNT(*)::int FROM baby_profiles
        WHERE id = ANY(%s::uuid[])
        """,
            (baby_ids,),
        ).fetchone()
    )
    print(f"  baby_profiles: {count} row(s)")
    if not dry_run and count:
        conn.execute(
            "DELETE FROM baby_profiles WHERE id = ANY(%s::uuid[])",
            (baby_ids,),
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", help="Owner/test user email in app_users")
    parser.add_argument("--firebase-uid", help="Firebase UID instead of email")
    parser.add_argument(
        "--all-babies",
        action="store_true",
        help="Delete every baby profile in the database (dev only).",
    )
    parser.add_argument(
        "--reset-onboarding",
        action="store_true",
        help="Clear owner_onboarding_completed_at for the resolved user.",
    )
    parser.add_argument(
        "--delete-app-user",
        action="store_true",
        help="Also delete the app_users row (after baby data).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print only; no deletes.")
    parser.add_argument("--verbose", action="store_true", help="Print GCS display paths.")
    args = parser.parse_args()

    if args.all_babies and not os.environ.get("LANONNA_DEV_CLEAR_ALL"):
        raise SystemExit(
            "Refusing --all-babies without LANONNA_DEV_CLEAR_ALL=1 (dev safety)."
        )

    with connect() as conn:
        if args.all_babies:
            baby_ids = _all_baby_ids(conn)
            uid = None
            if args.email or args.firebase_uid:
                user = _resolve_user(conn, args.email, args.firebase_uid)
                uid = user["firebase_uid"]
                print(f"Note: --all-babies deletes all babies, not only for {user['email']}")
        else:
            user = _resolve_user(conn, args.email, args.firebase_uid)
            uid = user["firebase_uid"]
            print(f"User: {user['email']} ({uid})")
            baby_ids = _baby_ids_for_user(conn, uid)

        if args.verbose:
            for path in _photo_paths(conn, baby_ids):
                print(f"  GCS display object (not deleted by this script): {path}")

        if args.dry_run:
            print("Dry run — no changes committed.")
            _delete_babies(conn, baby_ids, dry_run=True)
            return

        _delete_babies(conn, baby_ids, dry_run=False)

        if uid and args.reset_onboarding:
            conn.execute(
                """
                UPDATE app_users
                SET owner_onboarding_completed_at = NULL,
                    updated_at = now()
                WHERE firebase_uid = %s
                """,
                (uid,),
            )
            print("Reset owner_onboarding_completed_at.")

        if uid and args.delete_app_user:
            conn.execute("DELETE FROM app_users WHERE firebase_uid = %s", (uid,))
            print("Deleted app_users row.")

        conn.commit()
    print("Done.")


if __name__ == "__main__":
    main()
