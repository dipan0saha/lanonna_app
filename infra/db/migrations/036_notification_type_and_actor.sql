-- Structured inbox metadata: type + actor (written by worker, returned by API).

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS notification_type TEXT NOT NULL DEFAULT 'generic'
        CHECK (notification_type IN (
            'photo', 'event', 'registry', 'fun', 'comment', 'squish', 'digest', 'generic'
        )),
    ADD COLUMN IF NOT EXISTS actor_firebase_uid TEXT
        REFERENCES app_users (firebase_uid) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS actor_display_name TEXT;

-- Backfill type from deep_link and legacy English copy.
UPDATE notifications
SET notification_type = CASE
    WHEN lower(coalesce(deep_link, '')) LIKE '%/gallery%'
         OR lower(title || ' ' || body) LIKE '%photo%' THEN 'photo'
    WHEN lower(coalesce(deep_link, '')) LIKE '%/calendar%'
         OR lower(title || ' ' || body) LIKE '%event%'
         OR lower(title || ' ' || body) LIKE '%rsvp%' THEN 'event'
    WHEN lower(coalesce(deep_link, '')) LIKE '%/registry%'
         OR lower(title || ' ' || body) LIKE '%registry%' THEN 'registry'
    WHEN lower(coalesce(deep_link, '')) LIKE '%/fun%'
         OR lower(coalesce(deep_link, '')) LIKE '%gamification%'
         OR lower(title || ' ' || body) LIKE '%name%'
         OR lower(title || ' ' || body) LIKE '%vote%' THEN 'fun'
    WHEN lower(title || ' ' || body) LIKE '%comment%' THEN 'comment'
    WHEN lower(title || ' ' || body) LIKE '%squish%' THEN 'squish'
    WHEN lower(title) = 'your weekly update' THEN 'digest'
    ELSE 'generic'
END
WHERE notification_type = 'generic';

-- Backfill actor display name from title (non-generic) or body prefix before colon.
UPDATE notifications
SET actor_display_name = trim(title)
WHERE actor_display_name IS NULL
  AND trim(coalesce(title, '')) <> ''
  AND lower(trim(title)) NOT IN (
      'new comment', 'new squish', 'new rsvp', 'registry update',
      'calendar reminder', 'notification', 'new event', 'invite accepted',
      'baby has arrived!', 'your weekly update'
  );

UPDATE notifications
SET actor_display_name = trim(substring(body FROM '^([^:]+):'))
WHERE actor_display_name IS NULL
  AND body ~ '^[^:]+:';

UPDATE notifications
SET actor_display_name = trim(substring(body FROM '^([^\s]+)\s'))
WHERE actor_display_name IS NULL
  AND body ~ '^[^\s]+\s'
  AND lower(trim(coalesce(title, ''))) IN ('new comment', 'new squish', 'new rsvp');

INSERT INTO schema_migrations (version) VALUES ('036_notification_type_and_actor')
ON CONFLICT (version) DO NOTHING;
