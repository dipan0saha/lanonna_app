from __future__ import annotations

import uuid

from lanonna_api.db import get_connection
from lanonna_api.repositories.account_delete_media import (
    collect_and_delete_export_jobs,
    collect_photo_storage_for_babies,
    hard_delete_baby_profiles,
    purge_authored_photos_on_shared_babies,
)
from lanonna_api.repositories.active_participants import purge_participation
from lanonna_api.repositories.account_delete_user_data import (
    purge_personal_user_data,
    rerender_activity_summaries,
    tombstone_user,
)
from lanonna_api.repositories.memberships import (
    count_active_owners,
    soft_remove_all_memberships_for_user,
)
from lanonna_api.repositories.storage_cleanup_jobs import (
    StorageCleanupKind,
    insert_storage_cleanup_job,
)


def account_is_tombstoned(firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT deleted_at
            FROM app_users
            WHERE firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchone()
    return row is not None and row["deleted_at"] is not None


_SOLE_OWNED_BABIES_SQL = """
SELECT b.id, b.name
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
ORDER BY b.name NULLS LAST, b.created_at, b.id
"""


def list_sole_owned_baby_names(firebase_uid: str) -> list[dict[str, str | None]]:
    """``name`` is ``None`` for an unnamed baby; the app shows its fallback."""
    with get_connection() as conn:
        rows = conn.execute(_SOLE_OWNED_BABIES_SQL, (firebase_uid,)).fetchall()
    return [
        {"id": str(row["id"]), "name": row["name"]}
        for row in rows
    ]


def _lock_sole_owned_baby_ids(conn, firebase_uid: str) -> list[uuid.UUID]:
    """Lock every baby the user actively owns, then keep those with no other owner.

    The baby row lock is the one co-owner invite, accept and leave take, so an
    owner joining while the account is deleted either commits first (the baby is
    kept) or waits until the delete is done (the baby is already gone).
    """
    rows = conn.execute(
        """
        SELECT b.id
        FROM baby_profiles b
        JOIN baby_memberships m ON m.baby_profile_id = b.id
        WHERE m.firebase_uid = %s
          AND m.role = 'owner'
          AND m.removed_at IS NULL
        ORDER BY b.id
        FOR UPDATE OF b
        """,
        (firebase_uid,),
    ).fetchall()
    return [row["id"] for row in rows if count_active_owners(row["id"], conn) == 1]


def _email_for_update(conn, firebase_uid: str) -> str | None:
    row = conn.execute(
        "SELECT email FROM app_users WHERE firebase_uid = %s FOR UPDATE",
        (firebase_uid,),
    ).fetchone()
    return row["email"] if row else None


def delete_account_rows(firebase_uid: str) -> uuid.UUID:
    """Tombstone the user, hard-delete their sole-owned babies, and enqueue GCS
    cleanup, in one transaction. Returns the cleanup job id."""
    with get_connection() as conn:
        sole_owned = _lock_sole_owned_baby_ids(conn, firebase_uid)
        conn.execute(
            """
            UPDATE invitations
            SET status = 'revoked', updated_at = now()
            WHERE inviter_firebase_uid = %s AND status = 'pending'
            """,
            (firebase_uid,),
        )
        detached = purge_authored_photos_on_shared_babies(
            conn, firebase_uid, sole_owned
        )
        export_paths = collect_and_delete_export_jobs(
            conn, firebase_uid=firebase_uid, baby_profile_ids=sole_owned
        )
        if sole_owned:
            detached.extend(collect_photo_storage_for_babies(conn, sole_owned))
            hard_delete_baby_profiles(conn, sole_owned)
        soft_remove_all_memberships_for_user(firebase_uid, conn=conn)
        purge_participation(conn, firebase_uid)
        purge_personal_user_data(conn, firebase_uid, _email_for_update(conn, firebase_uid))
        job_id = insert_storage_cleanup_job(
            kind=StorageCleanupKind.ACCOUNT_DELETE,
            firebase_uid=firebase_uid,
            baby_profile_ids=sole_owned,
            detached_objects=detached,
            export_object_paths=export_paths,
            conn=conn,
        )
        tombstone_user(conn, firebase_uid)
        rerender_activity_summaries(conn, firebase_uid)
    return job_id
