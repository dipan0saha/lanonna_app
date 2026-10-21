"""Who counts as a participant on a baby (FR-SET-005, FR-INV-009, FR-INV-010).

A person counts only when their account is not tombstoned and they are a
current member of that baby (owner or follower, ``removed_at`` null). RSVPs,
votes, name loves, and squishes are presence: reads keep a row only for those
people, account deletion removes them everywhere, and ending a membership
removes them on that baby. Re-inviting restores the membership and does not
restore the purged rows. Comments, photos, name suggestions, and registry
claims are authored content and stay.
"""

from __future__ import annotations

import uuid

_ALIAS = "participant"
_MEMBERSHIP = "membership"


def active_participant_join(uid_column: str, baby_id_column: str) -> str:
    """Join the account and a current membership on ``baby_id_column``.

    ``baby_id_column`` is a column already in scope (the baby that owns the
    presence row, or a parent row joined for that purpose).
    """
    _assert_ident(uid_column)
    _assert_ident(baby_id_column)
    return (
        f"JOIN app_users {_ALIAS} "
        f"ON {_ALIAS}.firebase_uid = {uid_column} "
        f"AND {_ALIAS}.deleted_at IS NULL "
        f"JOIN baby_memberships {_MEMBERSHIP} "
        f"ON {_MEMBERSHIP}.firebase_uid = {uid_column} "
        f"AND {_MEMBERSHIP}.baby_profile_id = {baby_id_column} "
        f"AND {_MEMBERSHIP}.removed_at IS NULL"
    )


def purge_participation(conn, firebase_uid: str) -> None:
    """Remove presence rows for one account, on every baby. Table names are fixed."""
    for table in (
        "event_rsvps",
        "votes",
        "name_suggestion_likes",
        "photo_squishes",
        "announcement_squishes",
    ):
        conn.execute(
            f"DELETE FROM {table} WHERE firebase_uid = %s",
            (firebase_uid,),
        )


def purge_participation_on_baby(
    conn,
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> None:
    """Remove one person's presence on one baby. Other babies are left alone."""
    conn.execute(
        """
        DELETE FROM event_rsvps r
        USING events e
        WHERE r.event_id = e.id
          AND e.baby_profile_id = %s
          AND r.firebase_uid = %s
        """,
        (baby_profile_id, firebase_uid),
    )
    conn.execute(
        """
        DELETE FROM votes
        WHERE baby_profile_id = %s AND firebase_uid = %s
        """,
        (baby_profile_id, firebase_uid),
    )
    conn.execute(
        """
        DELETE FROM name_suggestion_likes l
        USING name_suggestions n
        WHERE l.name_suggestion_id = n.id
          AND n.baby_profile_id = %s
          AND l.firebase_uid = %s
        """,
        (baby_profile_id, firebase_uid),
    )
    conn.execute(
        """
        DELETE FROM photo_squishes s
        USING photos p
        WHERE s.photo_id = p.id
          AND p.baby_profile_id = %s
          AND s.firebase_uid = %s
        """,
        (baby_profile_id, firebase_uid),
    )
    conn.execute(
        """
        DELETE FROM announcement_squishes s
        USING birth_announcements a
        WHERE s.announcement_id = a.id
          AND a.baby_profile_id = %s
          AND s.firebase_uid = %s
        """,
        (baby_profile_id, firebase_uid),
    )


def _assert_ident(value: str) -> None:
    parts = value.split(".")
    if not parts or any(
        not part or not part.replace("_", "").isalnum() for part in parts
    ):
        raise ValueError(f"unsafe SQL identifier: {value}")
