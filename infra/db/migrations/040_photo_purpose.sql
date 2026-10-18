-- Issue #315: distinguish gallery shares from event cover attachments.

ALTER TABLE photos
    ADD COLUMN IF NOT EXISTS purpose TEXT NOT NULL DEFAULT 'gallery'
        CHECK (purpose IN ('gallery', 'event_cover'));

CREATE INDEX IF NOT EXISTS idx_photos_baby_gallery_created
    ON photos (baby_profile_id, created_at DESC)
    WHERE purpose = 'gallery';

INSERT INTO schema_migrations (version) VALUES ('040_photo_purpose')
ON CONFLICT (version) DO NOTHING;
