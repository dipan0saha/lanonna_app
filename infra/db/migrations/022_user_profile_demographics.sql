-- User profile demographics + terms acceptance (Complete Profile S04 / #391).

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS birth_date DATE,
    ADD COLUMN IF NOT EXISTS country_code CHAR(2),
    ADD COLUMN IF NOT EXISTS postal_code TEXT,
    ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ;

UPDATE app_users
SET terms_accepted_at = updated_at
WHERE display_name IS NOT NULL
  AND TRIM(display_name) <> ''
  AND terms_accepted_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('022_user_profile_demographics')
ON CONFLICT (version) DO NOTHING;
