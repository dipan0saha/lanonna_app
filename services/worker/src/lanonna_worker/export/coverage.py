"""Which tables a baby export must include.

The Postgres integration test loads every table that references the baby graph
and fails if it is not listed here. Add a new baby-scoped table to COVERED
(and a collector) or to EXCLUDED with a reason.
"""

from __future__ import annotations

from typing import Any

# Family content the owner export includes.
COVERED_TABLES: frozenset[str] = frozenset(
    {
        "baby_profiles",
        "baby_memberships",
        "photos",
        "photo_comments",
        "photo_squishes",
        "photo_baby_tags",
        "events",
        "event_rsvps",
        "event_comments",
        "registry_items",
        "registry_purchases",
        "name_suggestions",
        "name_suggestion_likes",
        "votes",
        "birth_announcements",
        "announcement_comments",
        "announcement_squishes",
        "invitations",
        "activity_events",
    }
)

# Present in the schema but not part of the baby archive.
EXCLUDED_TABLES: dict[str, str] = {
    "notifications": (
        "Per-user inbox rows. They are not the shared baby record and can "
        "reference other babies the requester follows."
    ),
    "baby_data_export_jobs": "Operational rows for this export feature.",
    "app_users": (
        "Identity directory. The export projects display names into people; "
        "it does not copy emails or Firebase UIDs."
    ),
    "device_tokens": "Push tokens are account credentials, not baby content.",
    "system_announcements": "Global product banners, not the birth announcement.",
    "announcement_dismissals": "Per-user dismissals of global banners.",
    "schema_migrations": "Schema bookkeeping.",
    "worker_delivery_log": "Worker idempotency bookkeeping.",
    "app_versions": "Minimum client version gate.",
}

# Tables whose rows belong to a baby even without a baby_profile_id column.
_BABY_GRAPH_TABLES = (
    "baby_profiles",
    "photos",
    "events",
    "registry_items",
    "name_suggestions",
    "birth_announcements",
)


def discover_baby_graph_tables(conn: Any) -> set[str]:
    """Tables that reference the baby graph (direct column or foreign key)."""
    rows = conn.execute(
        """
        SELECT DISTINCT c.relname AS table_name
        FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_class f ON f.oid = con.confrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND con.contype = 'f'
          AND f.relname = ANY(%s)
        """,
        (list(_BABY_GRAPH_TABLES),),
    ).fetchall()
    found = {row["table_name"] for row in rows}
    found.update(_BABY_GRAPH_TABLES)
    return found


def unclassified_tables(discovered: set[str]) -> set[str]:
    known = COVERED_TABLES | set(EXCLUDED_TABLES)
    return discovered - known
