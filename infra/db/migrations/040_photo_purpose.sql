-- Issue #315: distinguish gallery shares from event cover attachments.
-- Existing rows stay 'gallery' (no backfill).

ALTER TABLE photos
    ADD COLUMN IF NOT EXISTS purpose TEXT NOT NULL DEFAULT 'gallery'
        CHECK (purpose IN ('gallery', 'event_cover'));

CREATE INDEX IF NOT EXISTS idx_photos_baby_gallery_created
    ON photos (baby_profile_id, created_at DESC)
    WHERE purpose = 'gallery';

-- Deleting a photo clears any event cover that points at it (same as
-- birth_announcements.photo_id), so gallery delete never fails on the FK.
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_cover_photo_id_fkey;
ALTER TABLE events
    ADD CONSTRAINT events_cover_photo_id_fkey
        FOREIGN KEY (cover_photo_id) REFERENCES photos (id) ON DELETE SET NULL;

INSERT INTO schema_migrations (version) VALUES ('040_photo_purpose')
ON CONFLICT (version) DO NOTHING;
