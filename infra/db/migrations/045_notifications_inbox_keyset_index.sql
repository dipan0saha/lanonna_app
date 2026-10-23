-- Stable keyset pagination for inbox: ORDER BY created_at DESC, id DESC.

CREATE INDEX IF NOT EXISTS idx_notifications_user_created_id
    ON notifications (firebase_uid, created_at DESC, id DESC);

INSERT INTO schema_migrations (version) VALUES ('045_notifications_inbox_keyset_index')
ON CONFLICT (version) DO NOTHING;
