-- 044: baby profiles are hard-deleted (043), so the soft-delete column is unused.
-- Apply after the API and worker that no longer read it are deployed (contract step).

SET LOCAL lock_timeout = '5s';

ALTER TABLE baby_profiles DROP COLUMN IF EXISTS deleted_at;

INSERT INTO schema_migrations (version) VALUES ('044_drop_baby_profiles_deleted_at')
ON CONFLICT (version) DO NOTHING;
