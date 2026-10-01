-- Home activity stream (FR-HOME-007 foundation).

CREATE TABLE IF NOT EXISTS activity_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    actor_firebase_uid TEXT REFERENCES app_users (firebase_uid),
    event_type TEXT NOT NULL,
    summary TEXT NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_events_baby_created
    ON activity_events (baby_profile_id, created_at DESC);

INSERT INTO schema_migrations (version) VALUES ('006_home_activity')
ON CONFLICT (version) DO NOTHING;
