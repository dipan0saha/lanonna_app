"""Tombstoned accounts are not participants (FR-SET-005).

Account deletion anonymizes the profile and removes memberships. RSVPs, votes,
name loves, and squishes are that person's presence on a baby that remains, so
those reads keep a row only when ``app_users.deleted_at`` is null. Deletion
also removes the rows. Comments, photos, and name suggestions are authored
content: they stay, labeled with the anonymized display name, and comment
counts include them.
"""

from __future__ import annotations

_ALIAS = "participant"


def active_user_predicate(alias: str) -> str:
    """SQL predicate for an ``app_users`` alias already joined in the query."""
    _assert_ident(alias)
    return f"{alias}.deleted_at IS NULL"


def active_participant_join(uid_column: str) -> str:
    """Join ``app_users`` and keep only accounts that are not tombstoned."""
    _assert_ident(uid_column)
    return (
        f"JOIN app_users {_ALIAS} "
        f"ON {_ALIAS}.firebase_uid = {uid_column} "
        f"AND {_ALIAS}.deleted_at IS NULL"
    )


def purge_participation(conn, firebase_uid: str) -> None:
    """Remove presence rows for one account. Table names are fixed."""
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


def _assert_ident(value: str) -> None:
    parts = value.split(".")
    if not parts or any(
        not part or not part.replace("_", "").isalnum() for part in parts
    ):
        raise ValueError(f"unsafe SQL identifier: {value}")
