"""Every FK referencing column must have a supporting btree index (051 guard)."""

from __future__ import annotations

import pytest

from lanonna_api.db import get_connection

pytestmark = pytest.mark.integration

# (table, column): partial indexes, composite PK order, or theoretical parent DELETE
# only — see docs/engineering/rca/fk-indexes-photo-references.md.
_FK_INDEX_ALLOWLIST: dict[tuple[str, str], str] = {
    ("baby_memberships", "firebase_uid"): (
        "Hot path uses partial idx_baby_memberships_user (removed_at IS NULL); "
        "app_users are tombstoned, not deleted."
    ),
    ("event_rsvps", "firebase_uid"): (
        "Engagement uses partial idx_event_rsvps_firebase_uid_going; "
        "purge_participation table size is moderate."
    ),
    ("votes", "firebase_uid"): (
        "UNIQUE (baby_profile_id, firebase_uid, vote_type) does not lead with "
        "firebase_uid; few votes per user."
    ),
    ("photo_comments", "author_firebase_uid"): (
        "Partial author index excludes soft-deleted comments; tombstone not "
        "parent DELETE."
    ),
    ("event_comments", "author_firebase_uid"): (
        "Partial author index excludes soft-deleted comments."
    ),
    ("announcement_comments", "author_firebase_uid"): (
        "Partial author index excludes soft-deleted comments."
    ),
    ("biometric_credentials", "firebase_uid"): (
        "Partial unique on (firebase_uid, device_id) WHERE revoked_at IS NULL; "
        "account delete deletes all credentials in SQL."
    ),
    ("storage_cleanup_jobs", "firebase_uid"): (
        "Partial unique for in-flight account_delete jobs; completed rows kept "
        "for audit."
    ),
    ("announcement_dismissals", "firebase_uid"): (
        "PK leads with announcement_id; dismissals per user are tiny."
    ),
    ("events", "created_by_firebase_uid"): (
        "Author metadata only; app_users tombstone, no parent DELETE."
    ),
    ("registry_items", "created_by_firebase_uid"): (
        "Author metadata only."
    ),
    ("name_suggestions", "suggested_by_firebase_uid"): (
        "Author metadata only."
    ),
    ("birth_announcements", "created_by_firebase_uid"): (
        "Author metadata only."
    ),
    ("activity_events", "actor_firebase_uid"): (
        "Nullable actor; feed rerender on tombstone, not FK cascade."
    ),
    ("notifications", "actor_firebase_uid"): (
        "Account delete purges inbox rows in SQL; tombstone not parent DELETE."
    ),
    ("baby_profiles", "created_by_firebase_uid"): (
        "Onboarding metadata only."
    ),
}

_FK_COLUMNS_SQL = """
SELECT
    c.oid AS conoid,
    c.conrelid::regclass::text AS table_name,
    c.conname AS constraint_name,
    c.conkey AS attnums,
    array_agg(a.attname ORDER BY u.ord) AS columns
FROM pg_constraint c
CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS u(attnum, ord)
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = u.attnum
WHERE c.contype = 'f'
  AND c.connamespace = 'public'::regnamespace
GROUP BY c.oid, c.conrelid, c.conname, c.conkey
ORDER BY 2, 4
"""


def _table_indexes(conn) -> dict[str, list[tuple[tuple[str, ...], bool]]]:
    rows = conn.execute(
        """
        SELECT
            i.indrelid::regclass::text AS table_name,
            i.indpred IS NOT NULL AS is_partial,
            array_agg(a.attname ORDER BY k.ord) AS cols
        FROM pg_index i
        JOIN pg_class ic ON ic.oid = i.indexrelid
        CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS k(attnum, ord)
        JOIN pg_attribute a
          ON a.attrelid = i.indrelid AND a.attnum = k.attnum AND k.attnum > 0
        WHERE ic.relam = (SELECT oid FROM pg_am WHERE amname = 'btree')
        GROUP BY i.indrelid, i.indexrelid, i.indpred
        """
    ).fetchall()
    by_table: dict[str, list[tuple[tuple[str, ...], bool]]] = {}
    for row in rows:
        cols = tuple(row["cols"])
        if not cols:
            continue
        by_table.setdefault(row["table_name"], []).append((cols, row["is_partial"]))
    return by_table


def _fk_covered(
    indexes: list[tuple[tuple[str, ...], bool]],
    fk_columns: tuple[str, ...],
) -> bool:
    for idx_cols, is_partial in indexes:
        if len(idx_cols) < len(fk_columns):
            continue
        if idx_cols[: len(fk_columns)] != fk_columns:
            continue
        if not is_partial:
            return True
        # Nullable single-column FKs (e.g. cover_photo_id IS NOT NULL partials in 051).
        if len(fk_columns) == 1:
            return True
    return False


def test_every_foreign_key_has_a_covering_btree_index():
    with get_connection() as conn:
        fks = conn.execute(_FK_COLUMNS_SQL).fetchall()
        indexes = _table_indexes(conn)

    missing: list[str] = []
    for fk in fks:
        table = fk["table_name"]
        columns = tuple(fk["columns"])
        if _fk_covered(indexes.get(table, []), columns):
            continue
        allow_key = (table, columns[0]) if len(columns) == 1 else None
        if allow_key and allow_key in _FK_INDEX_ALLOWLIST:
            continue
        missing.append(
            f"{table}({', '.join(columns)}) via {fk['constraint_name']}"
        )

    assert not missing, (
        "FK column(s) lack a non-partial btree index with the FK as a left prefix. "
        "Add a migration index or an entry in _FK_INDEX_ALLOWLIST with rationale:\n"
        + "\n".join(f"  - {m}" for m in missing)
    )
