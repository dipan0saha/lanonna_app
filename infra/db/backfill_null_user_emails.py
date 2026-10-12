#!/usr/bin/env python3
"""Backfill active app_users rows whose email was cleared (#37).

Domain provisioning used to write email = NULL. Firebase Auth is the source
for the address. This script never updates tombstoned rows (deleted_at set,
email already scrubbed).

Dry-run is the default. Apply only against the intended database:

  cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5433
  export DB_PASSWORD="$(gcloud secrets versions access latest \\
    --secret=db-lanonna-app-password --project=lanonna-dev)"
  DB_PORT=5433 python backfill_null_user_emails.py
  DB_PORT=5433 python backfill_null_user_emails.py --apply

Requires Application Default Credentials that can call Firebase Auth
get_user (the lanonna-dev project). Rows whose Firebase user has no email
are counted and left null.

Pending invites addressed to a deleted account's former email are not
revoked. Invites are stored by email, not by uid. After the Firebase user
is deleted, a later account that verifies the same address may accept a
still-pending invite. That is intentional.

--report-orphans prints read-only counts of content created after a
tombstone (the check from #36). It does not delete anything.
"""

from __future__ import annotations

import argparse
import os
import sys

import firebase_admin
from firebase_admin import auth as firebase_auth
import psycopg
from psycopg.rows import dict_row


def connect() -> psycopg.Connection:
    password = os.environ.get("DB_PASSWORD")
    if not password:
        raise SystemExit("Set DB_PASSWORD (for example from Secret Manager).")
    return psycopg.connect(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=int(os.environ.get("DB_PORT", "5432")),
        user=os.environ.get("DB_USER", "lanonna_app"),
        dbname=os.environ.get("DB_NAME", "lanonna"),
        password=password,
        row_factory=dict_row,
    )


_ORPHAN_SQL = """
SELECT 'baby_memberships' AS kind, count(*) AS n
FROM baby_memberships m
JOIN app_users u USING (firebase_uid)
WHERE u.deleted_at IS NOT NULL AND m.created_at > u.deleted_at
UNION ALL
SELECT 'photos', count(*)
FROM photos p
JOIN app_users u ON u.firebase_uid = p.uploader_firebase_uid
WHERE u.deleted_at IS NOT NULL AND p.created_at > u.deleted_at
UNION ALL
SELECT 'photo_comments', count(*)
FROM photo_comments c
JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
WHERE u.deleted_at IS NOT NULL AND c.created_at > u.deleted_at
UNION ALL
SELECT 'event_comments', count(*)
FROM event_comments c
JOIN app_users u ON u.firebase_uid = c.author_firebase_uid
WHERE u.deleted_at IS NOT NULL AND c.created_at > u.deleted_at
UNION ALL
SELECT 'votes', count(*)
FROM votes v
JOIN app_users u ON u.firebase_uid = v.firebase_uid
WHERE u.deleted_at IS NOT NULL AND v.created_at > u.deleted_at
UNION ALL
SELECT 'tombstone_with_email', count(*)
FROM app_users
WHERE deleted_at IS NOT NULL AND email IS NOT NULL
"""


def report_orphans(conn: psycopg.Connection) -> None:
    print("Orphan / tombstone report (read-only):")
    for row in conn.execute(_ORPHAN_SQL).fetchall():
        print(f"  {row['kind']}: {row['n']}")


def backfill(conn: psycopg.Connection, *, apply: bool) -> None:
    rows = conn.execute(
        """
        SELECT firebase_uid
        FROM app_users
        WHERE email IS NULL
          AND deleted_at IS NULL
        ORDER BY created_at
        """
    ).fetchall()
    print(f"Active users with null email: {len(rows)}")
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    updated = 0
    skipped = 0
    missing = 0
    for row in rows:
        uid = row["firebase_uid"]
        try:
            record = firebase_auth.get_user(uid)
        except firebase_auth.UserNotFoundError:
            missing += 1
            print(f"  skip {uid}: Firebase user not found")
            continue
        email = (record.email or "").strip()
        if not email:
            skipped += 1
            print(f"  skip {uid}: Firebase user has no email")
            continue
        print(f"  {'update' if apply else 'would update'} {uid}")
        if apply:
            cur = conn.execute(
                """
                UPDATE app_users
                SET email = %s,
                    updated_at = now()
                WHERE firebase_uid = %s
                  AND email IS NULL
                  AND deleted_at IS NULL
                """,
                (email, uid),
            )
            updated += cur.rowcount
    if apply:
        conn.commit()
        print(f"Updated {updated}; skipped {skipped}; firebase missing {missing}")
    else:
        conn.rollback()
        print(
            f"Dry run. Would update rows that have a Firebase email; "
            f"skipped {skipped}; firebase missing {missing}. Re-run with --apply."
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write emails. Without this flag the script only prints a plan.",
    )
    parser.add_argument(
        "--report-orphans",
        action="store_true",
        help="Print read-only tombstone orphan counts and exit.",
    )
    args = parser.parse_args()
    with connect() as conn:
        if args.report_orphans:
            report_orphans(conn)
            return
        backfill(conn, apply=args.apply)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
