-- Inbox keyset pagination: GET /v1/me/notifications pages with
--   WHERE firebase_uid = $1 AND (created_at, id) < ($2, $3)
--   ORDER BY created_at DESC, id DESC
-- This index serves that query (and the first page) exactly. It supersedes
-- idx_notifications_user_created (firebase_uid, created_at DESC), which is a
-- strict prefix of it and has no other reader, so that one is dropped.
--
-- Plain CREATE INDEX (not CONCURRENTLY): apply_migrations.py runs every file in
-- one transaction. The build briefly blocks notification inserts; the table is
-- small and worker fan-out retries. lock_timeout fails the migration instead of
-- queueing behind a long-held lock. Idempotent via IF [NOT] EXISTS.
SET LOCAL lock_timeout = '5s';

CREATE INDEX IF NOT EXISTS idx_notifications_user_created_id
    ON notifications (firebase_uid, created_at DESC, id DESC);

DROP INDEX IF EXISTS idx_notifications_user_created;

INSERT INTO schema_migrations (version) VALUES ('045_notifications_inbox_keyset_index')
ON CONFLICT (version) DO NOTHING;
