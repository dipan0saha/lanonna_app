-- Link calendar events to static AI suggestion catalog entries (client asset).

ALTER TABLE events
    ADD COLUMN IF NOT EXISTS catalog_suggestion_id TEXT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_events_baby_catalog_suggestion
    ON events (baby_profile_id, catalog_suggestion_id)
    WHERE catalog_suggestion_id IS NOT NULL;

INSERT INTO schema_migrations (version) VALUES ('018_events_catalog_suggestion_id')
ON CONFLICT (version) DO NOTHING;
