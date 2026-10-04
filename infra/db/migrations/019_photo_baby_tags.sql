-- FR-GAL-008: tag which babies appear in a photo (metadata only).
CREATE TABLE IF NOT EXISTS photo_baby_tags (
    photo_id UUID NOT NULL REFERENCES photos (id) ON DELETE CASCADE,
    tagged_baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (photo_id, tagged_baby_profile_id)
);

CREATE INDEX IF NOT EXISTS idx_photo_baby_tags_tagged_baby
    ON photo_baby_tags (tagged_baby_profile_id);

INSERT INTO schema_migrations (version) VALUES ('019_photo_baby_tags')
ON CONFLICT (version) DO NOTHING;
