-- Calendar events, registry items, name suggestions (minimal v1 for onboarding seed).

CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    created_by_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    title TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_baby_starts
    ON events (baby_profile_id, starts_at);

CREATE TABLE IF NOT EXISTS registry_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    created_by_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    name TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_registry_items_baby
    ON registry_items (baby_profile_id, created_at DESC);

CREATE TABLE IF NOT EXISTS name_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    suggested_by_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    suggested_name TEXT NOT NULL,
    gender TEXT CHECK (gender IN ('male', 'female', 'unknown')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_name_suggestions_baby
    ON name_suggestions (baby_profile_id, created_at DESC);

INSERT INTO schema_migrations (version) VALUES ('004_onboarding_first_moment')
ON CONFLICT (version) DO NOTHING;
