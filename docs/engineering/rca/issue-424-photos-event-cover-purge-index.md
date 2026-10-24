# RCA: Missing index for stale `event_cover` purge scan (#424)

| Field | Value |
|-------|--------|
| **Issue** | [#424](https://github.com/dipan0saha/lanonna_app/issues/424) (item 3) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [#414](https://github.com/dipan0saha/lanonna_app/issues/414), [#416](https://github.com/dipan0saha/lanonna_app/issues/416) |

## Summary

The daily `purge-stale-event-covers` job (`lanonna_worker.event_cover_cleanup._stale_cover_ids`) selects from `photos` with `purpose = 'event_cover'`, `created_at < now() - interval`, unreferenced checks, `ORDER BY created_at, id`, and `LIMIT 500`. Without a supporting index, Postgres seq-scans `photos` as the gallery grows.

## Root cause

Migration `040_photo_purpose.sql` added `idx_photos_baby_gallery_created` for gallery list queries only (`WHERE purpose = 'gallery'`). The worker purge predicate and sort key were added in #414 but no partial index was added.

## Expected plan (after fix)

On a representative dev/prod-sized `photos` table, the candidate query should use a **Bitmap Index Scan** or **Index Scan** on:

```text
idx_photos_event_cover_created_id ON photos (created_at, id) WHERE purpose = 'event_cover'
```

Filter: `purpose = 'event_cover'` (partial index), `created_at < $cutoff`, plus heap filters for `NOT EXISTS` on `events` / `birth_announcements`. Sort order matches index `(created_at, id)`.

Example shape (run after migration in dev):

```sql
EXPLAIN (COSTS OFF)
SELECT p.id
FROM photos p
WHERE p.purpose = 'event_cover'
  AND p.created_at < now() - interval '24 hours'
  AND NOT EXISTS (SELECT 1 FROM events e WHERE e.cover_photo_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM birth_announcements a WHERE a.photo_id = p.id)
ORDER BY p.created_at, p.id
LIMIT 500;
```

## Fix

| Layer | Change |
|-------|--------|
| `infra/db/migrations/050_photos_event_cover_purge_index.sql` | Partial index `(created_at, id) WHERE purpose = 'event_cover'`, `lock_timeout` same as `045`. |

## Deploy notes

Apply migration `050` in dev (and prod on release). Worker image unchanged; no scheduler change.

## References

- `services/worker/src/lanonna_worker/event_cover_cleanup.py`
- `infra/db/migrations/040_photo_purpose.sql`
- `infra/db/migrations/050_photos_event_cover_purge_index.sql`
