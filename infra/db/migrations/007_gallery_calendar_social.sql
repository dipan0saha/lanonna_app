-- Gallery + calendar social (FR-GAL / FR-CAL).

ALTER TABLE photos
    ADD COLUMN IF NOT EXISTS caption TEXT;

CREATE INDEX IF NOT EXISTS idx_photos_baby_created_desc
    ON photos (baby_profile_id, created_at DESC);

ALTER TABLE events
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS location TEXT,
    ADD COLUMN IF NOT EXISTS video_call_url TEXT,
    ADD COLUMN IF NOT EXISTS cover_photo_id UUID REFERENCES photos (id),
    ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS photo_squishes (
    photo_id UUID NOT NULL REFERENCES photos (id) ON DELETE CASCADE,
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (photo_id, firebase_uid)
);

CREATE TABLE IF NOT EXISTS photo_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL REFERENCES photos (id) ON DELETE CASCADE,
    author_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_photo_comments_photo
    ON photo_comments (photo_id, created_at ASC)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS event_rsvps (
    event_id UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    status TEXT NOT NULL CHECK (status IN ('going', 'maybe', 'cant_go')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, firebase_uid)
);

CREATE TABLE IF NOT EXISTS event_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    author_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_event_comments_event
    ON event_comments (event_id, created_at ASC)
    WHERE deleted_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('007_gallery_calendar_social')
ON CONFLICT (version) DO NOTHING;
