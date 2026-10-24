"""Every FK must be backed by an index the parent-side FK check can use (051).

Postgres runs ``SELECT 1 FROM child WHERE fk = $1`` on every parent DELETE (and
key UPDATE), whatever the ON DELETE action. Without an index whose leading
columns are the FK columns, each parent delete seq-scans the child table.

A partial index serves that probe only when ``fk = $1`` implies its predicate,
i.e. ``fk IS NOT NULL`` on a single-column FK. Predicates such as
``deleted_at IS NULL`` or ``status = 'going'`` do not count.

The only exemption is a parent whose rows are never deleted. ``app_users`` is
tombstoned on account delete (``tombstone_user``), never deleted, so FKs to it
are indexed only where the account-delete path queries them by uid (see
docs/engineering/rca/fk-indexes-photo-references.md). The allowlist below names
those remaining FKs; the tests keep it honest in both directions.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from lanonna_api.db import get_connection

pytestmark = pytest.mark.integration

_REPO_ROOT = Path(__file__).resolve().parents[4]

# Parents whose rows production code never deletes.
_NEVER_DELETED_PARENTS = frozenset({"app_users"})

# FKs to a never-deleted parent with no FK-usable index: nothing deletes the
# parent, and no account-delete or hot query filters the child by this column.
_FK_INDEX_ALLOWLIST: dict[tuple[str, str], str] = {
    ("baby_memberships", "firebase_uid"): (
        "Every query filters removed_at IS NULL, served by partial "
        "idx_baby_memberships_user."
    ),
    ("event_comments", "author_firebase_uid"): (
        "Authored content kept on account delete; reads use partial author index."
    ),
    ("photo_comments", "author_firebase_uid"): (
        "Authored content kept on account delete; reads use partial author index."
    ),
    ("announcement_comments", "author_firebase_uid"): (
        "Authored content kept on account delete; reads use partial author index."
    ),
    ("storage_cleanup_jobs", "firebase_uid"): (
        "Only the in-flight account_delete guard reads by uid (partial unique)."
    ),
    ("events", "created_by_firebase_uid"): "Author attribution only.",
    ("registry_items", "created_by_firebase_uid"): "Author attribution only.",
    ("name_suggestions", "suggested_by_firebase_uid"): "Author attribution only.",
    ("birth_announcements", "created_by_firebase_uid"): "Author attribution only.",
    ("baby_profiles", "created_by_firebase_uid"): "Creator attribution only.",
}

_FKS_SQL = """
SELECT
    c.conname AS constraint_name,
    c.conrelid::regclass::text AS table_name,
    c.confrelid::regclass::text AS parent_table,
    array_agg(a.attname::text ORDER BY u.ord) AS columns
FROM pg_constraint c
CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS u(attnum, ord)
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = u.attnum
WHERE c.contype = 'f'
  AND c.connamespace = 'public'::regnamespace
GROUP BY c.oid, c.conname, c.conrelid, c.confrelid
ORDER BY 2, 1
"""

# Expression key columns (attnum 0) map to NULL so they never match an FK column.
_INDEXES_SQL = """
SELECT
    i.indrelid::regclass::text AS table_name,
    pg_get_expr(i.indpred, i.indrelid) AS predicate,
    array_agg(a.attname::text ORDER BY k.ord) AS columns
FROM pg_index i
JOIN pg_class ic ON ic.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = ic.relnamespace AND n.nspname = 'public'
CROSS JOIN LATERAL unnest(i.indkey[0:i.indnkeyatts - 1]) WITH ORDINALITY AS k(attnum, ord)
LEFT JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.attnum
WHERE ic.relam = (SELECT oid FROM pg_am WHERE amname = 'btree')
  AND i.indisvalid
GROUP BY i.indrelid, i.indexrelid, i.indpred
"""

# Every valid index in one schema, any access method, primary keys included:
# pg_get_indexdef spells out uniqueness, access method, key columns or
# expressions, opclass, collation, sort order, INCLUDE columns and the partial
# predicate, so two indexes with the same text minus the name are redundant.
_INDEXDEFS_SQL = """
SELECT
    i.indrelid::regclass::text AS table_name,
    ic.relname AS index_name,
    pg_get_indexdef(ic.oid) AS indexdef
FROM pg_index i
JOIN pg_class ic ON ic.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = ic.relnamespace AND n.nspname = %s
WHERE i.indisvalid
ORDER BY 1, 2
"""

# Index name is a plain or double-quoted identifier (quotes doubled inside).
_INDEXDEF_NAME_RE = re.compile(
    r'^CREATE (UNIQUE )?INDEX (?:"(?:[^"]|"")+"|[^\s"]+) ON ',
    re.IGNORECASE,
)


def _normalize_indexdef(indexdef: str) -> str:
    """``pg_get_indexdef`` with the index name removed for pairwise comparison."""
    normalized, n = _INDEXDEF_NAME_RE.subn(r"CREATE \1INDEX ON ", indexdef, count=1)
    assert n == 1, f"unexpected pg_get_indexdef shape: {indexdef}"
    return normalized


def find_duplicate_indexes(rows) -> list[str]:
    """Groups of 2+ indexes on one table whose definitions differ only by name."""
    groups: dict[tuple[str, str], list[str]] = {}
    for row in rows:
        key = (row["table_name"], _normalize_indexdef(row["indexdef"]))
        groups.setdefault(key, []).append(row["index_name"])
    return [
        f"{table}: {', '.join(sorted(names))} -> {normalized}"
        for (table, normalized), names in sorted(groups.items())
        if len(names) > 1
    ]


def _not_null_predicate(predicate: str, column: str) -> bool:
    return re.fullmatch(
        rf"\(?\s*{re.escape(column)}\s+IS\s+NOT\s+NULL\s*\)?", predicate, re.I
    ) is not None


def fk_covered(
    indexes: list[tuple[tuple[str | None, ...], str | None]],
    fk_columns: tuple[str, ...],
) -> bool:
    """True when some index can serve ``WHERE fk_col_1 = $1 AND ... = $n``."""
    n = len(fk_columns)
    for idx_columns, predicate in indexes:
        if len(idx_columns) < n or set(idx_columns[:n]) != set(fk_columns):
            continue
        if predicate is None:
            return True
        if n == 1 and _not_null_predicate(predicate, fk_columns[0]):
            return True
    return False


def _load():
    with get_connection() as conn:
        fks = conn.execute(_FKS_SQL).fetchall()
        rows = conn.execute(_INDEXES_SQL).fetchall()
    indexes: dict[str, list[tuple[tuple[str | None, ...], str | None]]] = {}
    for row in rows:
        indexes.setdefault(row["table_name"], []).append(
            (tuple(row["columns"]), row["predicate"])
        )
    return fks, indexes


def test_no_duplicate_index_definitions_on_one_table():
    with get_connection() as conn:
        rows = conn.execute(_INDEXDEFS_SQL, ("public",)).fetchall()
    duplicates = find_duplicate_indexes(rows)
    assert not duplicates, (
        "Two or more indexes share the same definition (method, columns or "
        "expressions, opclass, collation, order, INCLUDE, predicate, uniqueness). "
        "Drop the redundant one in a migration:\n"
        + "\n".join(f"  - {d}" for d in duplicates)
    )


def test_duplicate_guard_on_real_pg_get_indexdef_output():
    """Only true duplicates are flagged, using Postgres's own rendering."""
    with get_connection() as conn:
        with conn.transaction(force_rollback=True):
            conn.execute("CREATE SCHEMA dup_guard_probe")
            conn.execute(
                "CREATE TABLE dup_guard_probe.t "
                "(a int, b text, c timestamptz, d text, e int)"
            )
            conn.execute(
                "CREATE TABLE dup_guard_probe.u (a int, c timestamptz)"
            )
            for ddl in (
                # True duplicates (one quoted name), and a duplicate of the PK.
                "CREATE INDEX t_ac_1 ON dup_guard_probe.t (a, c DESC)",
                'CREATE INDEX "t ac 2" ON dup_guard_probe.t (a, c DESC)',
                "ALTER TABLE dup_guard_probe.t ADD CONSTRAINT t_pkey PRIMARY KEY (e)",
                "CREATE UNIQUE INDEX t_e_dup ON dup_guard_probe.t (e)",
                # Same partial predicate (written differently) is a duplicate.
                "CREATE INDEX t_pg_1 ON dup_guard_probe.t (a) WHERE d = 'gallery'",
                "CREATE INDEX t_pg_2 ON dup_guard_probe.t (a) WHERE (d = 'gallery')",
                # Not duplicates of the above or of each other.
                "CREATE INDEX t_ac_asc ON dup_guard_probe.t (a, c)",
                "CREATE UNIQUE INDEX t_ac_uq ON dup_guard_probe.t (a, c DESC)",
                "CREATE INDEX t_pc ON dup_guard_probe.t (a) WHERE d = 'event_cover'",
                "CREATE INDEX t_nn ON dup_guard_probe.t (a) WHERE a IS NOT NULL",
                "CREATE INDEX t_lower_b ON dup_guard_probe.t (lower(b))",
                "CREATE INDEX t_upper_b ON dup_guard_probe.t (upper(b))",
                "CREATE INDEX t_b ON dup_guard_probe.t (b)",
                'CREATE INDEX t_b_c ON dup_guard_probe.t (b COLLATE "C")',
                "CREATE INDEX t_b_pattern ON dup_guard_probe.t (b text_pattern_ops)",
                "CREATE INDEX t_b_hash ON dup_guard_probe.t USING hash (b)",
                "CREATE INDEX t_a_inc ON dup_guard_probe.t (a) INCLUDE (b)",
                "CREATE INDEX t_a_nf ON dup_guard_probe.t (a NULLS FIRST)",
                # Same columns on another table.
                "CREATE INDEX u_ac ON dup_guard_probe.u (a, c DESC)",
            ):
                conn.execute(ddl)
            rows = conn.execute(_INDEXDEFS_SQL, ("dup_guard_probe",)).fetchall()
            flagged = sorted(d.split(" -> ")[0] for d in find_duplicate_indexes(rows))
    assert flagged == [
        "dup_guard_probe.t: t ac 2, t_ac_1",
        "dup_guard_probe.t: t_e_dup, t_pkey",
        "dup_guard_probe.t: t_pg_1, t_pg_2",
    ]


def test_every_foreign_key_has_an_index_the_fk_check_can_use():
    fks, indexes = _load()
    missing = []
    for fk in fks:
        columns = tuple(fk["columns"])
        if fk_covered(indexes.get(fk["table_name"], []), columns):
            continue
        if len(columns) == 1 and (fk["table_name"], columns[0]) in _FK_INDEX_ALLOWLIST:
            continue
        missing.append(
            f"{fk['table_name']}({', '.join(columns)}) -> {fk['parent_table']} "
            f"via {fk['constraint_name']}"
        )
    assert not missing, (
        "FK column(s) lack an index with the FK as leading column (non-partial, "
        "or partial on '<fk> IS NOT NULL'). Add one in a migration:\n"
        + "\n".join(f"  - {m}" for m in missing)
    )


def test_allowlist_only_exempts_uncovered_fks_to_never_deleted_parents():
    fks, indexes = _load()
    by_key = {
        (fk["table_name"], fk["columns"][0]): fk
        for fk in fks
        if len(fk["columns"]) == 1
    }
    problems = []
    for key in _FK_INDEX_ALLOWLIST:
        fk = by_key.get(key)
        if fk is None:
            problems.append(f"{key}: no such single-column FK")
        elif fk["parent_table"] not in _NEVER_DELETED_PARENTS:
            problems.append(
                f"{key}: parent {fk['parent_table']} is deleted; index it instead"
            )
        elif fk_covered(indexes.get(key[0], []), (key[1],)):
            problems.append(f"{key}: now covered by an index; drop the entry")
    assert not problems, "\n".join(problems)


def test_never_deleted_parents_are_never_deleted_by_production_code():
    pattern = re.compile(
        r"DELETE\s+FROM\s+(" + "|".join(sorted(_NEVER_DELETED_PARENTS)) + r")\b",
        re.I,
    )
    offenders = []
    for src in ("services/api/src", "services/worker/src"):
        for path in (_REPO_ROOT / src).rglob("*.py"):
            if pattern.search(path.read_text(encoding="utf-8")):
                offenders.append(str(path.relative_to(_REPO_ROOT)))
    assert not offenders, (
        "These delete a parent the FK allowlist assumes is never deleted; index "
        "its FKs and shrink the allowlist:\n" + "\n".join(offenders)
    )


@pytest.mark.parametrize(
    ("indexes", "fk", "expected"),
    [
        ([(("a",), None)], ("a",), True),
        ([(("a", "b"), None)], ("a",), True),
        ([(("b", "a"), None)], ("a",), False),
        ([(("a",), "(a IS NOT NULL)")], ("a",), True),
        ([(("a",), "(deleted_at IS NULL)")], ("a",), False),
        ([(("a",), "(status = 'going'::text)")], ("a",), False),
        ([(("a", "b"), "(a IS NOT NULL)")], ("a", "b"), False),
        ([((None, "a"), None)], ("a",), False),
        ([(("b", "a"), None)], ("a", "b"), True),
    ],
)
def test_fk_covered_rules(indexes, fk, expected):
    assert fk_covered(indexes, fk) is expected


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            "CREATE INDEX idx_photos_baby_created ON public.photos "
            "USING btree (baby_profile_id, created_at DESC)",
            "CREATE INDEX ON public.photos USING btree (baby_profile_id, created_at DESC)",
        ),
        (
            "CREATE UNIQUE INDEX photos_pkey ON public.photos USING btree (id)",
            "CREATE UNIQUE INDEX ON public.photos USING btree (id)",
        ),
        (
            'CREATE INDEX "odd "" name ON x" ON public.t USING btree (a) '
            "WHERE (b = 'ON x'::text)",
            "CREATE INDEX ON public.t USING btree (a) WHERE (b = 'ON x'::text)",
        ),
        (
            "CREATE INDEX i ON ONLY public.p USING btree (a)",
            "CREATE INDEX ON ONLY public.p USING btree (a)",
        ),
    ],
)
def test_normalize_indexdef_strips_name_only(raw, expected):
    assert _normalize_indexdef(raw) == expected


def _row(table, name, indexdef):
    return {"table_name": table, "index_name": name, "indexdef": indexdef}


def test_find_duplicate_indexes_grouping():
    rows = [
        _row("public.p", "a1", "CREATE INDEX a1 ON public.p USING btree (x, y DESC)"),
        _row("public.p", "a2", "CREATE INDEX a2 ON public.p USING btree (x, y DESC)"),
        _row("public.p", "a3", "CREATE INDEX a3 ON public.p USING btree (x, y)"),
        _row("public.p", "e1", "CREATE INDEX e1 ON public.p USING btree (lower(z))"),
        _row("public.p", "e2", "CREATE INDEX e2 ON public.p USING btree (z)"),
        _row(
            "public.p", "w1",
            "CREATE INDEX w1 ON public.p USING btree (x) WHERE (k = 'a'::text)",
        ),
        _row(
            "public.p", "w2",
            "CREATE INDEX w2 ON public.p USING btree (x) WHERE (k = 'b'::text)",
        ),
        _row("public.q", "b1", "CREATE INDEX b1 ON public.q USING btree (x, y DESC)"),
    ]
    assert find_duplicate_indexes(rows) == [
        "public.p: a1, a2 -> CREATE INDEX ON public.p USING btree (x, y DESC)"
    ]
