-- Birth announcement keepsake (prototype announcement-create / announcement-card)

CREATE TABLE IF NOT EXISTS birth_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL UNIQUE REFERENCES baby_profiles(id) ON DELETE CASCADE,
    photo_id UUID REFERENCES photos(id) ON DELETE SET NULL,
    first_name TEXT,
    last_name TEXT,
    gender TEXT,
    birth_date DATE,
    birth_time TEXT,
    weight_text TEXT,
    length_text TEXT,
    created_by_firebase_uid TEXT NOT NULL REFERENCES app_users(firebase_uid),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS announcement_squishes (
    announcement_id UUID NOT NULL REFERENCES birth_announcements(id) ON DELETE CASCADE,
    firebase_uid TEXT NOT NULL REFERENCES app_users(firebase_uid),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (announcement_id, firebase_uid)
);

CREATE TABLE IF NOT EXISTS announcement_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID NOT NULL REFERENCES birth_announcements(id) ON DELETE CASCADE,
    author_firebase_uid TEXT NOT NULL REFERENCES app_users(firebase_uid),
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_announcement_comments_announcement
    ON announcement_comments(announcement_id, created_at DESC);
