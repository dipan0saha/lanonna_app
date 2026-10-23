"""Personal user data removed on account delete (FR-SET-005, issue #364).

``app_users`` is tombstoned, not deleted, so ``ON DELETE CASCADE`` on child
FKs never runs. ``delete_account_rows`` calls these in its one transaction:

- ``purge_personal_user_data`` (before the tombstone) removes what a cascade
  would have removed, the inbox rows other people got about this person, and
  the invitation history addressed to their email.
- ``tombstone_user`` clears every profile column that identifies the person.
- ``rerender_activity_summaries`` (after the tombstone) rewrites the English
  diagnostic ``activity_events.summary`` that embedded their old name.

Authored content on shared babies (comments, suggestions, registry claims and
items, events, activity rows) stays under "Deleted user"; see
``active_participants`` and ``docs/engineering/rca/account-deletion-user-data-audit.md``.
Migration ``046`` applies the same rules to accounts deleted before this.
"""

from __future__ import annotations

from typing import Any

from lanonna_activity_copy import activity_summary

TOMBSTONE_DISPLAY_NAME = "Deleted user"

_PERSONAL_TABLES = (
    "notifications",
    "device_tokens",
    "announcement_dismissals",
    "biometric_credentials",
)


def purge_personal_user_data(conn: Any, firebase_uid: str, email: str | None) -> None:
    """Delete inbox, push targets, banner dismissals, biometric keys and
    invitation history that belong to or name one account."""
    for table in _PERSONAL_TABLES:
        conn.execute(f"DELETE FROM {table} WHERE firebase_uid = %s", (firebase_uid,))
    # Other people's inbox rows about this person: title/body embed their name.
    conn.execute(
        "DELETE FROM notifications WHERE actor_firebase_uid = %s",
        (firebase_uid,),
    )
    if email:
        # Invites they received and settled. Pending invites stay: they are the
        # inviter's open offer and expire on their own.
        conn.execute(
            """
            DELETE FROM invitations
            WHERE lower(invitee_email) = lower(%s) AND status <> 'pending'
            """,
            (email,),
        )


def tombstone_user(conn: Any, firebase_uid: str) -> None:
    """Keep the row for attribution; clear everything that identifies the person."""
    conn.execute(
        """
        UPDATE app_users
        SET display_name = %s,
            email = NULL,
            avatar_url = NULL,
            phone = NULL,
            birth_date = NULL,
            country_code = NULL,
            postal_code = NULL,
            last_seen_at = NULL,
            biometric_unlock_enabled = false,
            deleted_at = now()
        WHERE firebase_uid = %s
        """,
        (TOMBSTONE_DISPLAY_NAME, firebase_uid),
    )


def rerender_activity_summaries(conn: Any, firebase_uid: str) -> None:
    """Re-render ``summary`` for feed rows where the account is actor or target.

    Run after ``tombstone_user`` so the live name lookup returns the tombstone.
    """
    rows = conn.execute(
        """
        SELECT e.id, e.event_type, e.params,
               NULLIF(TRIM(a.display_name), '') AS actor,
               NULLIF(TRIM(t.display_name), '') AS target
        FROM activity_events e
        LEFT JOIN app_users a ON a.firebase_uid = e.actor_firebase_uid
        LEFT JOIN app_users t ON t.firebase_uid = e.payload->>'target_firebase_uid'
        WHERE e.actor_firebase_uid = %s
           OR e.payload->>'target_firebase_uid' = %s
        """,
        (firebase_uid, firebase_uid),
    ).fetchall()
    for row in rows:
        summary = activity_summary(
            row["event_type"],
            row["params"] or {},
            actor=row["actor"] or "Someone",
            target=row["target"] or "a member",
        )
        conn.execute(
            "UPDATE activity_events SET summary = %s WHERE id = %s",
            (summary, row["id"]),
        )
