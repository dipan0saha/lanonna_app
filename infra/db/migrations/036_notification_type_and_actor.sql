-- Structured inbox metadata: type + actor (written by worker, returned by API).
-- Forward-only like every migration here; re-running is a no-op.

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS notification_type TEXT NOT NULL DEFAULT 'generic',
    ADD COLUMN IF NOT EXISTS actor_firebase_uid TEXT
        REFERENCES app_users (firebase_uid) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS actor_display_name TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'notifications_notification_type_check'
    ) THEN
        ALTER TABLE notifications
            ADD CONSTRAINT notifications_notification_type_check
            CHECK (notification_type IN (
                'photo', 'event', 'registry', 'fun', 'comment', 'squish',
                'digest', 'generic'
            ));
    END IF;
END $$;

-- Backfill legacy rows deterministically: the fixed titles the API has always
-- published, then the deep link route. No body/copy matching. Legacy rows keep
-- a NULL actor: names cannot be recovered reliably from copy.
UPDATE notifications
SET notification_type = CASE
    WHEN title = 'New comment' THEN 'comment'
    WHEN title = 'New squish' THEN 'squish'
    WHEN title IN ('New event', 'New RSVP') THEN 'event'
    WHEN title = 'Registry update' THEN 'registry'
    WHEN deep_link LIKE '/gallery/%' THEN 'photo'
    WHEN deep_link LIKE '/calendar/%' THEN 'event'
    WHEN deep_link LIKE '/registry%' THEN 'registry'
    WHEN deep_link LIKE '/fun%' THEN 'fun'
    ELSE 'generic'
END
WHERE notification_type = 'generic';

INSERT INTO schema_migrations (version) VALUES ('036_notification_type_and_actor')
ON CONFLICT (version) DO NOTHING;
