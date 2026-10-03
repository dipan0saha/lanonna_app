-- Per-channel notification preferences (FR-NOTIF-004).

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS notify_gallery_enabled BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS notify_calendar_enabled BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS notify_registry_enabled BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS notify_comments_enabled BOOLEAN NOT NULL DEFAULT true;

INSERT INTO schema_migrations (version) VALUES ('016_notification_channels')
ON CONFLICT (version) DO NOTHING;
