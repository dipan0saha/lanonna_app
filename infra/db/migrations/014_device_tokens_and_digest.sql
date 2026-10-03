-- FCM device tokens and weekly digest bookkeeping.

CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_firebase_uid
    ON device_tokens (firebase_uid);

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS last_weekly_digest_at TIMESTAMPTZ;

INSERT INTO schema_migrations (version) VALUES ('014_device_tokens_and_digest')
ON CONFLICT (version) DO NOTHING;
