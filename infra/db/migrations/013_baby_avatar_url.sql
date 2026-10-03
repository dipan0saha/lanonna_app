-- Baby profile avatar (display media URL from signed upload).

ALTER TABLE baby_profiles
    ADD COLUMN IF NOT EXISTS avatar_url TEXT;

INSERT INTO schema_migrations (version) VALUES ('013_baby_avatar_url')
ON CONFLICT (version) DO NOTHING;
