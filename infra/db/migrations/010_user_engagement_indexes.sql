-- Indexes for account engagement stats aggregates (no new tables).

CREATE INDEX IF NOT EXISTS idx_photo_squishes_firebase_uid
    ON photo_squishes (firebase_uid);

CREATE INDEX IF NOT EXISTS idx_announcement_squishes_firebase_uid
    ON announcement_squishes (firebase_uid);

CREATE INDEX IF NOT EXISTS idx_registry_purchases_purchased_by
    ON registry_purchases (purchased_by_firebase_uid);

CREATE INDEX IF NOT EXISTS idx_event_rsvps_firebase_uid_going
    ON event_rsvps (firebase_uid)
    WHERE status = 'going';

CREATE INDEX IF NOT EXISTS idx_photo_comments_author
    ON photo_comments (author_firebase_uid)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_event_comments_author
    ON event_comments (author_firebase_uid)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_announcement_comments_author
    ON announcement_comments (author_firebase_uid)
    WHERE deleted_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('010_user_engagement_indexes')
ON CONFLICT (version) DO NOTHING;
