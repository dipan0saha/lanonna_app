-- FR-SET-004 / NFR-FORCE-001: minimum client version per platform.
CREATE TABLE IF NOT EXISTS app_versions (
    platform TEXT PRIMARY KEY CHECK (platform IN ('android', 'ios')),
    minimum_version TEXT NOT NULL,
    store_url TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO app_versions (platform, minimum_version, store_url) VALUES
    ('android', '1.0.0', 'https://play.google.com/store/apps/details?id=com.lanonna.lanonna'),
    ('ios', '1.0.0', 'https://apps.apple.com/app/id000000000')
ON CONFLICT (platform) DO NOTHING;

INSERT INTO schema_migrations (version) VALUES ('020_app_versions')
ON CONFLICT (version) DO NOTHING;
