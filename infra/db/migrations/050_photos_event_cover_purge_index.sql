-- Stale event-cover purge: worker _stale_cover_ids filters purpose = event_cover,
-- created_at < cutoff, orders by created_at, id (see event_cover_cleanup.py).
SET LOCAL lock_timeout = '5s';

CREATE INDEX IF NOT EXISTS idx_photos_event_cover_created_id
    ON photos (created_at, id)
    WHERE purpose = 'event_cover';

INSERT INTO schema_migrations (version) VALUES ('050_photos_event_cover_purge_index')
ON CONFLICT (version) DO NOTHING;
