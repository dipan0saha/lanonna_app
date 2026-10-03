-- In-app notifications (inbox) and user notification preferences.

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS notification_digest TEXT NOT NULL DEFAULT 'realtime'
        CHECK (notification_digest IN ('realtime', 'daily', 'weekly')),
    ADD COLUMN IF NOT EXISTS push_notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS email_digest_enabled BOOLEAN NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid) ON DELETE CASCADE,
    baby_profile_id UUID REFERENCES baby_profiles (id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    deep_link TEXT,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications (firebase_uid, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications (firebase_uid, created_at DESC)
    WHERE read_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('011_notifications_and_prefs')
ON CONFLICT (version) DO NOTHING;
