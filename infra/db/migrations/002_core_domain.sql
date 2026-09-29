-- Core baby + photo domain (v1 product foundation).

CREATE TABLE IF NOT EXISTS baby_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    expected_birth_date DATE,
    actual_birth_date DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'unknown')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS baby_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    role TEXT NOT NULL CHECK (role IN ('owner', 'follower')),
    relationship_label TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    removed_at TIMESTAMPTZ,
    UNIQUE (baby_profile_id, firebase_uid)
);

CREATE INDEX IF NOT EXISTS idx_baby_memberships_user
    ON baby_memberships (firebase_uid)
    WHERE removed_at IS NULL;

CREATE TABLE IF NOT EXISTS photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id),
    uploader_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'ready', 'failed')),
    display_path TEXT,
    thumb_path TEXT,
    content_type TEXT,
    byte_length INTEGER,
    display_object_generation BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_photos_display_object_generation
    ON photos (display_object_generation)
    WHERE display_object_generation IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_photos_baby_created
    ON photos (baby_profile_id, created_at DESC);

INSERT INTO schema_migrations (version) VALUES ('002_core_domain')
ON CONFLICT (version) DO NOTHING;
