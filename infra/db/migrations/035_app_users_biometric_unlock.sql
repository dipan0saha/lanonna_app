-- Optional biometric unlock preference (PRD §5.3 / M-31).

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS biometric_unlock_enabled BOOLEAN NOT NULL DEFAULT false;

INSERT INTO schema_migrations (version) VALUES ('035_app_users_biometric_unlock')
ON CONFLICT (version) DO NOTHING;
