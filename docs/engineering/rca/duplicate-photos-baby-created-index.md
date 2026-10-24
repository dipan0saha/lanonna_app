# RCA: Duplicate `photos` baby gallery list indexes

| Field | Value |
|-------|--------|
| **Issue** | (none — owner chose no GitHub issue) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [fk-indexes-photo-references.md](./fk-indexes-photo-references.md) (`photos.baby_profile_id` FK coverage) |

## Summary

The `photos` table had two btree indexes on the same key: `(baby_profile_id, created_at DESC)`, with no partial predicate, INCLUDE columns, or uniqueness. They differed only in name. Migration `052` drops `idx_photos_baby_created_desc` and keeps `idx_photos_baby_created`.

## Root cause

Migration `002_core_domain.sql` added `idx_photos_baby_created` when `photos` was introduced. Migration `007_gallery_calendar_social.sql` added gallery/caption work and created `idx_photos_baby_created_desc` with the same column list and sort order. No later migration removed the duplicate; `040_photo_purpose.sql` added a separate partial index `idx_photos_baby_gallery_created` for `purpose = 'gallery'` only.

## Evidence they are identical

Both definitions in migration source (no `WHERE`, no `UNIQUE`, default btree/collation):

```sql
-- 002_core_domain.sql
CREATE INDEX IF NOT EXISTS idx_photos_baby_created
    ON photos (baby_profile_id, created_at DESC);

-- 007_gallery_calendar_social.sql
CREATE INDEX IF NOT EXISTS idx_photos_baby_created_desc
    ON photos (baby_profile_id, created_at DESC);
```

On a live schema after `051`, `pg_get_indexdef` for each index normalizes to the same shape (only the index name differs):

```text
CREATE INDEX ON public.photos USING btree (baby_profile_id, created_at DESC)
```

`pg_index` shows both non-unique, non-partial btree indexes with the same `indkey` / `indoption` (DESC on `created_at`).

## Why dropping one is safe

| Concern | After `052` |
|---------|-------------|
| Gallery list / favorites sort (`ORDER BY p.created_at DESC`, `photos.py`) | `idx_photos_baby_created` still supports `baby_profile_id = $1` with `created_at DESC`. |
| Gallery-only lists (`purpose = 'gallery'`) | `idx_photos_baby_gallery_created` (partial, `040`) remains. |
| Baby hard-delete / FK check on `photos.baby_profile_id` | Leading column `baby_profile_id` on the kept index; `test_fk_index_coverage_postgres.py` still passes. |
| Event-cover purge | Uses `idx_photos_event_cover_created_id` (`050`), unrelated. |

No application code, worker, or script referenced either index by name (only the migration files).

## Naming choice

Repo convention encodes sort direction in the index definition, not a `_desc` suffix on the name — e.g. `idx_activity_events_baby_created`, `idx_baby_data_export_jobs_baby_created`. The `_desc` suffix on the duplicate was dropped.

## Fix

| Layer | Change |
|-------|--------|
| `infra/db/migrations/052_drop_duplicate_photos_baby_created_index.sql` | `DROP INDEX IF EXISTS idx_photos_baby_created_desc`, `lock_timeout` 5s. |
| `services/api/tests/integration/test_fk_index_coverage_postgres.py` | Guard: fail when two valid indexes on one table (any access method, primary keys included) share the same `pg_get_indexdef` minus the name. That text carries uniqueness, method, columns or expressions, opclass, collation, sort order, `INCLUDE` and the partial predicate, so expression indexes and partials with different predicates are never flagged. A probe test builds real indexes in a rolled-back scratch schema to prove it, and the guard fails on the pre-`052` schema. |

## Deploy notes

Indexes only, no API or worker change. Safe before or after any deploy.

## References

- `infra/db/migrations/002_core_domain.sql`
- `infra/db/migrations/007_gallery_calendar_social.sql`
- `infra/db/migrations/052_drop_duplicate_photos_baby_created_index.sql`
- `services/api/src/lanonna_api/repositories/photos.py`
