"""Personal user data removed on account delete (FR-SET-005 / Play data deletion).

``app_users`` is tombstoned, not deleted, so PostgreSQL ``ON DELETE CASCADE`` on
child FKs does not run. This module mirrors what those cascades would remove,
plus actor anonymization where ``ON DELETE SET NULL`` would apply.

Authored content on shared babies (comments, suggestions, registry claims,
activity stream rows, ended memberships, historical invitations) is handled
elsewhere and intentionally retained with the tombstoned display name.
"""

from __future__ import annotations

from typing import Any


def purge_personal_user_data(conn: Any, firebase_uid: str) -> None:
    """Delete inbox, push targets, and other personal artifacts for one account."""
    conn.execute(
        """
        UPDATE notifications
        SET actor_firebase_uid = NULL,
            actor_display_name = NULL
        WHERE actor_firebase_uid = %s
        """,
        (firebase_uid,),
    )
    conn.execute(
        "DELETE FROM notifications WHERE firebase_uid = %s",
        (firebase_uid,),
    )
    conn.execute(
        "DELETE FROM device_tokens WHERE firebase_uid = %s",
        (firebase_uid,),
    )
    conn.execute(
        "DELETE FROM announcement_dismissals WHERE firebase_uid = %s",
        (firebase_uid,),
    )
    conn.execute(
        "DELETE FROM biometric_credentials WHERE firebase_uid = %s",
        (firebase_uid,),
    )
