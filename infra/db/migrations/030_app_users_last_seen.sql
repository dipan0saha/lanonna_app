-- Throttle last-seen writes during request-scoped user provisioning (#36).

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

INSERT INTO schema_migrations (version) VALUES ('030_app_users_last_seen')
ON CONFLICT (version) DO NOTHING;
