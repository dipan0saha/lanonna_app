-- Registry social + gamification (FR-REG / FR-GAM).

ALTER TABLE registry_items
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS product_url TEXT;

CREATE INDEX IF NOT EXISTS idx_registry_items_baby_priority
    ON registry_items (baby_profile_id, priority DESC, created_at DESC);

ALTER TABLE baby_profiles
    ADD COLUMN IF NOT EXISTS registry_shipping_address TEXT;

CREATE TABLE IF NOT EXISTS registry_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registry_item_id UUID NOT NULL UNIQUE REFERENCES registry_items (id) ON DELETE CASCADE,
    purchased_by_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    vote_type TEXT NOT NULL CHECK (vote_type IN ('gender', 'birthdate')),
    gender_value TEXT CHECK (gender_value IN ('male', 'female')),
    predicted_birth_date DATE,
    is_anonymous BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (baby_profile_id, firebase_uid, vote_type)
);

CREATE INDEX IF NOT EXISTS idx_votes_baby_type
    ON votes (baby_profile_id, vote_type);

CREATE TABLE IF NOT EXISTS name_suggestion_likes (
    name_suggestion_id UUID NOT NULL REFERENCES name_suggestions (id) ON DELETE CASCADE,
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (name_suggestion_id, firebase_uid)
);

CREATE INDEX IF NOT EXISTS idx_name_suggestion_likes_user
    ON name_suggestion_likes (firebase_uid);

INSERT INTO schema_migrations (version) VALUES ('008_registry_fun_social')
ON CONFLICT (version) DO NOTHING;
