-- Link registry items to static AI suggestion catalog entries (client asset).

ALTER TABLE registry_items
    ADD COLUMN IF NOT EXISTS catalog_suggestion_id TEXT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_registry_items_baby_catalog_suggestion
    ON registry_items (baby_profile_id, catalog_suggestion_id)
    WHERE catalog_suggestion_id IS NOT NULL;

INSERT INTO schema_migrations (version) VALUES ('017_registry_catalog_suggestion_id')
ON CONFLICT (version) DO NOTHING;
