-- Stale event-cover purge (#424): lanonna_worker.event_cover_cleanup._stale_cover_ids
--   WHERE purpose = 'event_cover' AND created_at < now() - interval
--   ORDER BY created_at, id LIMIT n
-- The partial index matches that predicate and sort key, so the daily job reads
-- only event covers, oldest first, instead of scanning every gallery photo.
--
-- Plain CREATE INDEX (not CONCURRENTLY): apply_migrations.py runs every file in
-- one transaction (same as 045). Event covers are a small slice of photos, so the
-- build is short; lock_timeout fails the migration instead of queueing behind a
-- long-held lock. Idempotent via IF NOT EXISTS.
SET LOCAL lock_timeout = '5s';

CREATE INDEX IF NOT EXISTS idx_photos_event_cover_created_id
    ON photos (created_at, id)
    WHERE purpose = 'event_cover';

INSERT INTO schema_migrations (version) VALUES ('050_photos_event_cover_purge_index')
ON CONFLICT (version) DO NOTHING;
