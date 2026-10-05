#!/usr/bin/env python3
"""Hard-delete a user and sole-owned baby data (SQL + optional GCS + Firebase).

Dev / QA cleanup only. Co-owned baby profiles are kept; this user is removed
from memberships and their comments, RSVPs, votes, uploads on those babies, etc.

  cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5433

  ./scripts/hard_delete_user.sh you@example.com

Use ``--dry-run`` to preview. Do not run against Maestro smoke / QA fixture emails.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth
import psycopg

from clear_dev_test_data import _resolve_user, _scalar, connect

_PROTECTED_EMAIL_RE = re.compile(
    r"^lanonna\.dev\.(smoke|qa\.(owner|follower))@test\.com$",
    re.IGNORECASE,
)


def _require_not_protected(email: str) -> None:
    if _PROTECTED_EMAIL_RE.match(email.strip()):
        raise SystemExit(
            f"Refusing to hard-delete protected fixture email {email}. "
            "Use a disposable test account."
        )


def list_sole_owned_baby_ids(conn: psycopg.Connection, firebase_uid: str) -> list[str]:
    rows = conn.execute(
        """
        SELECT b.id::text
        FROM baby_profiles b
        JOIN baby_memberships m ON m.baby_profile_id = b.id
        WHERE m.firebase_uid = %s
          AND m.role = 'owner'
          AND m.removed_at IS NULL
          AND (
            SELECT COUNT(*)::int
            FROM baby_memberships om
            WHERE om.baby_profile_id = b.id
              AND om.role = 'owner'
              AND om.removed_at IS NULL
          ) = 1
        """,
        (firebase_uid,),
    ).fetchall()
    return [_scalar(r) for r in rows]


def _collect_photo_storage_paths(
    conn: psycopg.Connection,
    baby_ids: list[str],
    extra_photo_ids: list[str] | None = None,
) -> list[tuple[str, str]]:
    """Return (bucket_kind, object_name) where bucket_kind is display|thumb."""
    out: list[tuple[str, str]] = []
    if baby_ids:
        rows = conn.execute(
            """
            SELECT display_path, thumb_path
            FROM photos
            WHERE baby_profile_id = ANY(%s::uuid[])
            """,
            (baby_ids,),
        ).fetchall()
        for row in rows:
            if row.get("display_path"):
                out.append(("display", row["display_path"]))
            if row.get("thumb_path"):
                out.append(("thumb", row["thumb_path"]))
    if extra_photo_ids:
        rows = conn.execute(
            """
            SELECT display_path, thumb_path FROM photos WHERE id = ANY(%s::uuid[])
            """,
            (extra_photo_ids,),
        ).fetchall()
        for row in rows:
            if row.get("display_path"):
                out.append(("display", row["display_path"]))
            if row.get("thumb_path"):
                out.append(("thumb", row["thumb_path"]))
    return out


def _collect_avatar_paths(
    conn: psycopg.Connection,
    firebase_uid: str,
    baby_ids: list[str],
) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    row = conn.execute(
        "SELECT avatar_url FROM app_users WHERE firebase_uid = %s",
        (firebase_uid,),
    ).fetchone()
    if row and row.get("avatar_url"):
        path = _object_path_from_db_value(row["avatar_url"])
        if path:
            out.append(("display", path))
    if baby_ids:
        rows = conn.execute(
            """
            SELECT avatar_url FROM baby_profiles
            WHERE id = ANY(%s::uuid[]) AND avatar_url IS NOT NULL
            """,
            (baby_ids,),
        ).fetchall()
        for r in rows:
            path = _object_path_from_db_value(r["avatar_url"])
            if path:
                out.append(("display", path))
    return out


def _object_path_from_db_value(value: str) -> str | None:
    value = value.strip()
    if not value:
        return None
    if value.startswith("http://") or value.startswith("https://"):
        # Legacy public URL: .../bucket/object or bucket.storage.googleapis.com/object
        display_bucket = os.environ.get("DISPLAY_BUCKET", "lanonna-dev-display")
        if f"/{display_bucket}/" in value:
            return value.split(f"/{display_bucket}/", 1)[1].split("?", 1)[0]
        if f"{display_bucket}.storage.googleapis.com/" in value:
            return value.split(f"{display_bucket}.storage.googleapis.com/", 1)[1].split(
                "?", 1
            )[0]
        return None
    if value.startswith(f"{os.environ.get('DISPLAY_BUCKET', 'lanonna-dev-display')}/"):
        return value.split("/", 1)[1]
    return value


def _hard_delete_babies(
    conn: psycopg.Connection,
    baby_ids: list[str],
    dry_run: bool,
) -> None:
    if not baby_ids:
        return
    print(f"Hard-deleting {len(baby_ids)} sole-owned baby profile(s).")

    steps: list[tuple[str, str, tuple[Any, ...]]] = [
        (
            "events.cover_photo_id cleared",
            """
            UPDATE events SET cover_photo_id = NULL
            WHERE baby_profile_id = ANY(%s::uuid[])
            """,
            (baby_ids,),
        ),
        (
            "announcement_comments",
            """
            DELETE FROM announcement_comments
            WHERE announcement_id IN (
                SELECT id FROM birth_announcements
                WHERE baby_profile_id = ANY(%s::uuid[])
            )
            """,
            (baby_ids,),
        ),
        (
            "announcement_squishes",
            """
            DELETE FROM announcement_squishes
            WHERE announcement_id IN (
                SELECT id FROM birth_announcements
                WHERE baby_profile_id = ANY(%s::uuid[])
            )
            """,
            (baby_ids,),
        ),
        (
            "birth_announcements",
            "DELETE FROM birth_announcements WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "photo_baby_tags",
            """
            DELETE FROM photo_baby_tags
            WHERE photo_id IN (SELECT id FROM photos WHERE baby_profile_id = ANY(%s::uuid[]))
               OR tagged_baby_profile_id = ANY(%s::uuid[])
            """,
            (baby_ids, baby_ids),
        ),
        (
            "registry_purchases",
            """
            DELETE FROM registry_purchases
            WHERE registry_item_id IN (
                SELECT id FROM registry_items WHERE baby_profile_id = ANY(%s::uuid[])
            )
            """,
            (baby_ids,),
        ),
        (
            "name_suggestion_likes",
            """
            DELETE FROM name_suggestion_likes
            WHERE name_suggestion_id IN (
                SELECT id FROM name_suggestions WHERE baby_profile_id = ANY(%s::uuid[])
            )
            """,
            (baby_ids,),
        ),
        (
            "event_comments",
            """
            DELETE FROM event_comments
            WHERE event_id IN (SELECT id FROM events WHERE baby_profile_id = ANY(%s::uuid[]))
            """,
            (baby_ids,),
        ),
        (
            "event_rsvps",
            """
            DELETE FROM event_rsvps
            WHERE event_id IN (SELECT id FROM events WHERE baby_profile_id = ANY(%s::uuid[]))
            """,
            (baby_ids,),
        ),
        (
            "photo_comments",
            """
            DELETE FROM photo_comments
            WHERE photo_id IN (SELECT id FROM photos WHERE baby_profile_id = ANY(%s::uuid[]))
            """,
            (baby_ids,),
        ),
        (
            "photo_squishes",
            """
            DELETE FROM photo_squishes
            WHERE photo_id IN (SELECT id FROM photos WHERE baby_profile_id = ANY(%s::uuid[]))
            """,
            (baby_ids,),
        ),
        (
            "photos",
            "DELETE FROM photos WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "events",
            "DELETE FROM events WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "registry_items",
            "DELETE FROM registry_items WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "votes",
            "DELETE FROM votes WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "name_suggestions",
            "DELETE FROM name_suggestions WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "activity_events",
            "DELETE FROM activity_events WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "invitations",
            "DELETE FROM invitations WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "baby_data_export_jobs",
            "DELETE FROM baby_data_export_jobs WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "baby_memberships",
            "DELETE FROM baby_memberships WHERE baby_profile_id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
        (
            "baby_profiles",
            "DELETE FROM baby_profiles WHERE id = ANY(%s::uuid[])",
            (baby_ids,),
        ),
    ]

    for label, sql, params in steps:
        if dry_run:
            print(f"  [dry-run] {label}")
            continue
        conn.execute(sql, params)
        print(f"  {label}")


def _purge_user_on_remaining_babies(
    conn: psycopg.Connection,
    firebase_uid: str,
    deleted_baby_ids: list[str],
    dry_run: bool,
) -> None:
    """Remove user footprint on co-owned / follower babies."""
    print("Purging user rows on other babies (memberships, social, uploads).")

    if deleted_baby_ids:
        extra_photo_rows = conn.execute(
            """
            SELECT id::text FROM photos
            WHERE uploader_firebase_uid = %s
              AND NOT (baby_profile_id = ANY(%s::uuid[]))
            """,
            (firebase_uid, deleted_baby_ids),
        ).fetchall()
    else:
        extra_photo_rows = conn.execute(
            """
            SELECT id::text FROM photos WHERE uploader_firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchall()
    extra_photo_ids = [_scalar(r) for r in extra_photo_rows]

    if extra_photo_ids:
        if dry_run:
            print(f"  [dry-run] delete {len(extra_photo_ids)} uploaded photo(s) on shared babies")
        else:
            conn.execute(
                "UPDATE events SET cover_photo_id = NULL WHERE cover_photo_id = ANY(%s::uuid[])",
                (extra_photo_ids,),
            )
            conn.execute(
                "DELETE FROM photo_baby_tags WHERE photo_id = ANY(%s::uuid[])",
                (extra_photo_ids,),
            )
            conn.execute(
                "DELETE FROM photo_comments WHERE photo_id = ANY(%s::uuid[])",
                (extra_photo_ids,),
            )
            conn.execute(
                "DELETE FROM photo_squishes WHERE photo_id = ANY(%s::uuid[])",
                (extra_photo_ids,),
            )
            conn.execute("DELETE FROM photos WHERE id = ANY(%s::uuid[])", (extra_photo_ids,))

    def _delete_on_shared_babies(label: str, sql: str) -> None:
        if deleted_baby_ids:
            full_sql = sql + " AND NOT (baby_profile_id = ANY(%s::uuid[]))"
            params: tuple[Any, ...] = (firebase_uid, deleted_baby_ids)
        else:
            full_sql = sql
            params = (firebase_uid,)
        if dry_run:
            print(f"  [dry-run] {label}")
            return
        conn.execute(full_sql, params)
        print(f"  {label}")

    if dry_run:
        print("  [dry-run] events (created by user)")
    else:
        if deleted_baby_ids:
            conn.execute(
                """
                UPDATE events SET cover_photo_id = NULL
                WHERE created_by_firebase_uid = %s
                  AND NOT (baby_profile_id = ANY(%s::uuid[]))
                """,
                (firebase_uid, deleted_baby_ids),
            )
            conn.execute(
                """
                DELETE FROM events
                WHERE created_by_firebase_uid = %s
                  AND NOT (baby_profile_id = ANY(%s::uuid[]))
                """,
                (firebase_uid, deleted_baby_ids),
            )
        else:
            conn.execute(
                "UPDATE events SET cover_photo_id = NULL WHERE created_by_firebase_uid = %s",
                (firebase_uid,),
            )
            conn.execute(
                "DELETE FROM events WHERE created_by_firebase_uid = %s",
                (firebase_uid,),
            )
        print("  events (created by user)")
    _delete_on_shared_babies(
        "registry_items (created by user)",
        "DELETE FROM registry_items WHERE created_by_firebase_uid = %s",
    )
    _delete_on_shared_babies(
        "name_suggestions (created by user)",
        """
        DELETE FROM name_suggestions WHERE suggested_by_firebase_uid = %s
        """,
    )

    if dry_run:
        print("  [dry-run] birth_announcements (created by user)")
    else:
        conn.execute(
            """
            DELETE FROM announcement_comments
            WHERE announcement_id IN (
                SELECT id FROM birth_announcements WHERE created_by_firebase_uid = %s
            )
            """,
            (firebase_uid,),
        )
        conn.execute(
            """
            DELETE FROM announcement_squishes
            WHERE announcement_id IN (
                SELECT id FROM birth_announcements WHERE created_by_firebase_uid = %s
            )
            """,
            (firebase_uid,),
        )
        conn.execute(
            "DELETE FROM birth_announcements WHERE created_by_firebase_uid = %s",
            (firebase_uid,),
        )
        print("  birth_announcements (created by user)")

    user_steps: list[tuple[str, str]] = [
        ("invitations (inviter)", "DELETE FROM invitations WHERE inviter_firebase_uid = %s"),
        ("photo_squishes", "DELETE FROM photo_squishes WHERE firebase_uid = %s"),
        ("photo_comments", "DELETE FROM photo_comments WHERE author_firebase_uid = %s"),
        ("event_rsvps", "DELETE FROM event_rsvps WHERE firebase_uid = %s"),
        ("event_comments", "DELETE FROM event_comments WHERE author_firebase_uid = %s"),
        ("registry_purchases", "DELETE FROM registry_purchases WHERE purchased_by_firebase_uid = %s"),
        ("votes", "DELETE FROM votes WHERE firebase_uid = %s"),
        ("name_suggestion_likes", "DELETE FROM name_suggestion_likes WHERE firebase_uid = %s"),
        ("announcement_squishes", "DELETE FROM announcement_squishes WHERE firebase_uid = %s"),
        (
            "announcement_comments",
            "DELETE FROM announcement_comments WHERE author_firebase_uid = %s",
        ),
        ("announcement_dismissals", "DELETE FROM announcement_dismissals WHERE firebase_uid = %s"),
        (
            "activity_events (actor)",
            "DELETE FROM activity_events WHERE actor_firebase_uid = %s",
        ),
        ("baby_memberships", "DELETE FROM baby_memberships WHERE firebase_uid = %s"),
        ("notifications", "DELETE FROM notifications WHERE firebase_uid = %s"),
        ("device_tokens", "DELETE FROM device_tokens WHERE firebase_uid = %s"),
    ]

    for label, sql in user_steps:
        if dry_run:
            print(f"  [dry-run] {label}")
            continue
        conn.execute(sql, (firebase_uid,))
        print(f"  {label}")


def _delete_gcs_objects(
    objects: list[tuple[str, str]],
    dry_run: bool,
) -> None:
    if not objects:
        return
    display_bucket = os.environ.get("DISPLAY_BUCKET", "lanonna-dev-display")
    thumb_bucket = os.environ.get("THUMBNAILS_BUCKET", "lanonna-dev-thumbnails")

    if dry_run:
        for kind, name in objects:
            bucket = display_bucket if kind == "display" else thumb_bucket
            print(f"  [dry-run] GCS delete gs://{bucket}/{name}")
        return

    try:
        from google.cloud import storage
    except ImportError:
        print(
            "google-cloud-storage not installed; skipping GCS deletes. "
            "pip install google-cloud-storage",
            file=sys.stderr,
        )
        return

    client = storage.Client()
    by_bucket: dict[str, set[str]] = {}
    for kind, name in objects:
        bucket = display_bucket if kind == "display" else thumb_bucket
        by_bucket.setdefault(bucket, set()).add(name)

    for bucket_name, names in by_bucket.items():
        bucket = client.bucket(bucket_name)
        for name in sorted(names):
            blob = bucket.blob(name)
            if blob.exists():
                blob.delete()
                print(f"  GCS deleted gs://{bucket_name}/{name}")
            else:
                print(f"  GCS missing gs://{bucket_name}/{name}")


def _delete_firebase_user(firebase_uid: str, dry_run: bool) -> None:
    if dry_run:
        print(f"[dry-run] Firebase delete_user({firebase_uid})")
        return
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    try:
        firebase_auth.delete_user(firebase_uid)
        print("Firebase user deleted.")
    except firebase_auth.UserNotFoundError:
        print("Firebase user not found (already deleted).")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True, help="User email in app_users")
    parser.add_argument("--dry-run", action="store_true", help="Preview only; no changes.")
    parser.add_argument("--skip-gcs", action="store_true", help="Do not delete GCS objects.")
    parser.add_argument(
        "--skip-firebase",
        action="store_true",
        help="Do not delete Firebase Auth user.",
    )
    args = parser.parse_args()

    email = args.email.strip()
    _require_not_protected(email)

    with connect() as conn:
        user = _resolve_user(conn, email, None)
        uid = user["firebase_uid"]
        print(f"User: {user['email']} ({uid})")

        sole_owned = list_sole_owned_baby_ids(conn, uid)
        storage_paths = _collect_photo_storage_paths(conn, sole_owned)
        if sole_owned:
            extra_photos = conn.execute(
                """
                SELECT id::text FROM photos
                WHERE uploader_firebase_uid = %s
                  AND NOT (baby_profile_id = ANY(%s::uuid[]))
                """,
                (uid, sole_owned),
            ).fetchall()
        else:
            extra_photos = conn.execute(
                "SELECT id::text FROM photos WHERE uploader_firebase_uid = %s",
                (uid,),
            ).fetchall()
        extra_ids = [_scalar(r) for r in extra_photos]
        storage_paths.extend(_collect_photo_storage_paths(conn, [], extra_ids))
        storage_paths.extend(_collect_avatar_paths(conn, uid, sole_owned))

        if args.dry_run:
            print("Dry run — no SQL/Firebase/GCS commits.")

        _hard_delete_babies(conn, sole_owned, dry_run=args.dry_run)
        _purge_user_on_remaining_babies(conn, uid, sole_owned, dry_run=args.dry_run)

        if not args.dry_run:
            conn.execute("DELETE FROM app_users WHERE firebase_uid = %s", (uid,))
            print("Deleted app_users row.")
            conn.commit()

        if not args.skip_gcs:
            _delete_gcs_objects(storage_paths, dry_run=args.dry_run)
        if not args.skip_firebase:
            _delete_firebase_user(uid, dry_run=args.dry_run)

    print("Done.")


if __name__ == "__main__":
    main()
