-- Structured notification and activity rows: what happened (kind / event_type)
-- plus display params. The app renders every sentence from ARB; title / body /
-- summary stay as English diagnostic copy. Forward-only; re-running is a no-op.

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS notification_kind TEXT,
    ADD COLUMN IF NOT EXISTS params JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE activity_events
    ADD COLUMN IF NOT EXISTS params JSONB NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'notifications_notification_kind_check'
    ) THEN
        ALTER TABLE notifications
            ADD CONSTRAINT notifications_notification_kind_check
            CHECK (notification_kind IS NULL OR notification_kind IN (
                'photo_shared', 'photo_squished', 'photo_commented',
                'event_created', 'event_rsvp', 'event_commented',
                'registry_purchased', 'registry_buying',
                'invite_accepted', 'baby_arrived'
            ));
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Legacy inbox rows. The fixed titles the API always published select the
-- kind (same deterministic rule as 036); params come only from structured
-- source rows located by the deep link or baby id. No body text is parsed.
-- Rows whose params cannot be derived that way (RSVP status, which registry
-- message it was) keep a NULL kind and the app shows their stored text.
-- ---------------------------------------------------------------------------

UPDATE notifications SET notification_kind = 'photo_squished'
WHERE notification_kind IS NULL AND title = 'New squish';

UPDATE notifications SET notification_kind = 'photo_shared'
WHERE notification_kind IS NULL AND title = 'New photo';

UPDATE notifications SET notification_kind = 'photo_commented'
WHERE notification_kind IS NULL
  AND title = 'New comment'
  AND deep_link ~ '^/gallery/photo/[0-9a-fA-F-]{36}$';

UPDATE notifications n
SET notification_kind = CASE n.title
        WHEN 'New event' THEN 'event_created'
        ELSE 'event_commented'
    END,
    params = jsonb_strip_nulls(jsonb_build_object('event_title', e.title))
FROM events e
WHERE n.notification_kind IS NULL
  AND n.title IN ('New event', 'New comment')
  AND e.id = substring(n.deep_link FROM '^/calendar/event/([0-9a-fA-F-]{36})$')::uuid;

UPDATE notifications n
SET notification_kind = CASE n.title
        WHEN 'Invite accepted' THEN 'invite_accepted'
        ELSE 'baby_arrived'
    END,
    params = jsonb_strip_nulls(jsonb_build_object('baby_name', NULLIF(btrim(b.name), '')))
FROM baby_profiles b
WHERE n.notification_kind IS NULL
  AND n.title IN ('Invite accepted', 'Baby has arrived!')
  AND b.id = n.baby_profile_id;

-- ---------------------------------------------------------------------------
-- Legacy activity rows (params = '{}'). A follower's registry claim becomes
-- its own type (its fixed summary always began 'Someone is buying "'); display
-- values come from the referenced rows. Rows whose source was deleted keep
-- empty params and the app shows their stored summary.
-- ---------------------------------------------------------------------------

UPDATE activity_events SET event_type = 'registry_claimed'
WHERE event_type = 'registry_purchased'
  AND summary LIKE 'Someone is buying "%';

UPDATE activity_events a
SET params = jsonb_strip_nulls(jsonb_build_object('caption', btrim(p.caption)))
FROM photos p
WHERE a.params = '{}'::jsonb
  AND a.event_type IN ('photo_shared', 'photo_squish', 'photo_comment')
  AND p.id = substring(a.payload->>'photo_id' FROM '^([0-9a-fA-F-]{36})$')::uuid
  AND btrim(COALESCE(p.caption, '')) <> '';

UPDATE activity_events a
SET params = jsonb_strip_nulls(jsonb_build_object('item_name', r.name))
FROM registry_items r
WHERE a.params = '{}'::jsonb
  AND a.event_type IN ('registry_item_added', 'registry_purchased', 'registry_claimed')
  AND r.id = substring(a.payload->>'registry_item_id' FROM '^([0-9a-fA-F-]{36})$')::uuid;

UPDATE activity_events a
SET params = jsonb_strip_nulls(jsonb_build_object('event_title', e.title))
FROM events e
WHERE a.params = '{}'::jsonb
  AND a.event_type = 'event_created'
  AND e.id = substring(a.payload->>'event_id' FROM '^([0-9a-fA-F-]{36})$')::uuid;

UPDATE activity_events a
SET params = jsonb_strip_nulls(jsonb_build_object('suggested_name', s.suggested_name))
FROM name_suggestions s
WHERE a.params = '{}'::jsonb
  AND a.event_type = 'name_suggested'
  AND s.id = substring(a.payload->>'name_suggestion_id' FROM '^([0-9a-fA-F-]{36})$')::uuid;

-- The API wrote exactly one of these two summaries for every gender guess.
UPDATE activity_events
SET params = jsonb_build_object(
        'gender',
        CASE summary WHEN 'Guessed "male"' THEN 'male' ELSE 'female' END
    )
WHERE params = '{}'::jsonb
  AND event_type = 'gender_vote_cast'
  AND summary IN ('Guessed "male"', 'Guessed "female"');

UPDATE activity_events a
SET params = jsonb_strip_nulls(jsonb_build_object('baby_name', NULLIF(btrim(b.name), '')))
FROM baby_profiles b
WHERE a.params = '{}'::jsonb
  AND a.event_type = 'baby_arrived'
  AND b.id = a.baby_profile_id;

INSERT INTO schema_migrations (version) VALUES ('038_structured_notification_activity_params')
ON CONFLICT (version) DO NOTHING;
