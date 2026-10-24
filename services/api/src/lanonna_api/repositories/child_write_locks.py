"""Row locks that keep baby-scoped child writes safe against hard-delete (#442).

Hard-delete paths (``hard_delete_baby_profile_if_sole_owner``, account delete,
leave/remove) take ``SELECT ... FOR UPDATE`` on ``baby_profiles`` before they
delete or change membership. A writer that INSERTs a row which references a baby
(directly, or through a photo / event / announcement / suggestion / registry item
the baby owns) first takes ``FOR KEY SHARE`` here, in the **same transaction** as
the INSERT:

- if delete holds the baby, the writer waits, then sees the row gone and raises
  :class:`NotFoundError` (HTTP 404 ``not_found``) instead of a foreign-key 500;
- if the writer holds the baby, delete waits for it and then cascades the new row.

Lock order, every path: ``baby_profiles`` rows first, ascending ``id`` when more
than one (same order as account delete), then the direct parent row, then the
INSERT. A transaction must take these locks before it locks or deletes any other
row that a baby delete cascades into, or the two can deadlock.
"""

from __future__ import annotations

import uuid
from collections.abc import Iterable
from enum import StrEnum
from typing import Any

from psycopg import sql

from lanonna_api.domain.errors import ErrorCode, NotFoundError


class ChildWriteParent(StrEnum):
    """Baby-owned tables whose rows other rows reference (``ON DELETE CASCADE``)."""

    PHOTOS = "photos"
    EVENTS = "events"
    BIRTH_ANNOUNCEMENTS = "birth_announcements"
    NAME_SUGGESTIONS = "name_suggestions"
    REGISTRY_ITEMS = "registry_items"


_PARENT_NOT_FOUND = {
    ChildWriteParent.PHOTOS: "Photo not found.",
    ChildWriteParent.EVENTS: "Event not found.",
    ChildWriteParent.BIRTH_ANNOUNCEMENTS: "Announcement not found.",
    ChildWriteParent.NAME_SUGGESTIONS: "Suggestion not found.",
    ChildWriteParent.REGISTRY_ITEMS: "Registry item not found.",
}


def ensure_baby_profiles_for_child_write(
    baby_profile_ids: Iterable[uuid.UUID],
    conn: Any,
) -> None:
    """``FOR KEY SHARE`` each baby in ascending id order; 404 if any is gone."""
    for baby_profile_id in sorted(set(baby_profile_ids)):
        row = conn.execute(
            "SELECT id FROM baby_profiles WHERE id = %s FOR KEY SHARE",
            (baby_profile_id,),
        ).fetchone()
        if row is None:
            raise NotFoundError(ErrorCode.NOT_FOUND, "Baby profile not found.")


def ensure_baby_profile_for_child_write(baby_profile_id: uuid.UUID, conn: Any) -> None:
    """``FOR KEY SHARE`` one baby before a child INSERT; 404 if it is gone."""
    ensure_baby_profiles_for_child_write((baby_profile_id,), conn)


def ensure_parent_row_for_child_write(
    parent: ChildWriteParent,
    row_id: uuid.UUID,
    conn: Any,
    *,
    also_baby_ids: Iterable[uuid.UUID] = (),
) -> None:
    """Lock the parent's baby (plus ``also_baby_ids``), then the parent row.

    Raises :class:`NotFoundError` when the parent or its baby is gone, so a
    comment / squish / RSVP / like / purchase racing a delete gets a 404.
    """
    table = sql.Identifier(ChildWriteParent(parent).value)
    not_found = _PARENT_NOT_FOUND[ChildWriteParent(parent)]
    owner = conn.execute(
        sql.SQL("SELECT baby_profile_id FROM {} WHERE id = %s").format(table),
        (row_id,),
    ).fetchone()
    if owner is None:
        raise NotFoundError(ErrorCode.NOT_FOUND, not_found)
    ensure_baby_profiles_for_child_write(
        (owner["baby_profile_id"], *also_baby_ids), conn
    )
    locked = conn.execute(
        sql.SQL("SELECT 1 FROM {} WHERE id = %s FOR KEY SHARE").format(table),
        (row_id,),
    ).fetchone()
    if locked is None:
        raise NotFoundError(ErrorCode.NOT_FOUND, not_found)
