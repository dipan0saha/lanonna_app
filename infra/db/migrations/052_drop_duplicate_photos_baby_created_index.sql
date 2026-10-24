-- Duplicate gallery list index: 002 created idx_photos_baby_created and 007
-- created idx_photos_baby_created_desc, both btree on
-- (baby_profile_id, created_at DESC) with no partial predicate. Keep
-- idx_photos_baby_created (matches idx_activity_events_baby_created and other
-- baby+created_at indexes that encode DESC in the column list, not the name).
-- See docs/engineering/rca/duplicate-photos-baby-created-index.md.
--
-- Plain DROP INDEX (not CONCURRENTLY): apply_migrations.py runs every file in
-- one transaction (same as 045/050/051). lock_timeout fails the migration
-- instead of queueing behind a long-held lock. Idempotent via IF EXISTS.
SET LOCAL lock_timeout = '5s';

DROP INDEX IF EXISTS idx_photos_baby_created_desc;

INSERT INTO schema_migrations (version) VALUES ('052_drop_duplicate_photos_baby_created_index')
ON CONFLICT (version) DO NOTHING;
