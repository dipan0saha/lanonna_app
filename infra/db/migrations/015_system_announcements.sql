-- System-wide dismissible home banners (PRD §6.2 #4)

CREATE TABLE IF NOT EXISTS system_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    cta_label TEXT,
    cta_deep_link TEXT,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at TIMESTAMPTZ,
    target_audience TEXT NOT NULL DEFAULT 'all'
        CHECK (target_audience IN ('all', 'owners', 'followers')),
    priority INT NOT NULL DEFAULT 0,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS announcement_dismissals (
    announcement_id UUID NOT NULL REFERENCES system_announcements(id) ON DELETE CASCADE,
    firebase_uid TEXT NOT NULL REFERENCES app_users(firebase_uid),
    dismissed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (announcement_id, firebase_uid)
);

CREATE INDEX IF NOT EXISTS idx_system_announcements_active
    ON system_announcements (starts_at, ends_at)
    WHERE deleted_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('015_system_announcements')
ON CONFLICT (version) DO NOTHING;
