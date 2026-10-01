-- User profile avatar (OAuth URL or future uploaded asset URL).

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS avatar_url TEXT;

INSERT INTO schema_migrations (version) VALUES ('005_user_avatar_url')
ON CONFLICT (version) DO NOTHING;
