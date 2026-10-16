-- Backfill actor_firebase_uid (and display name) for legacy inbox rows where the
-- actor can be resolved from structured sources (deep_link UUIDs, notification_type,
-- and source tables). No title/body text matching. Idempotent: only NULL actors.

-- Gallery photo UUID from deep_link (/gallery/photo/{uuid}).
CREATE OR REPLACE FUNCTION _notification_photo_id(deep_link TEXT)
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        substring(deep_link FROM '/gallery/photo/([0-9a-fA-F-]{36})'),
        ''
    )::uuid;
$$;

CREATE OR REPLACE FUNCTION _notification_event_id(deep_link TEXT)
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        substring(deep_link FROM '/calendar/event/([0-9a-fA-F-]{36})'),
        ''
    )::uuid;
$$;

CREATE OR REPLACE FUNCTION _notification_baby_id_from_followers_link(deep_link TEXT)
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(
        substring(deep_link FROM '/baby/([0-9a-fA-F-]{36})/followers'),
        ''
    )::uuid;
$$;

-- photo_comments: latest comment on the photo at or before the notification time.
UPDATE notifications n
SET actor_firebase_uid = src.author_firebase_uid
FROM LATERAL (
    SELECT c.author_firebase_uid
    FROM photo_comments c
    WHERE c.deleted_at IS NULL
      AND c.photo_id = _notification_photo_id(n.deep_link)
      AND c.created_at <= n.created_at + interval '2 seconds'
    ORDER BY c.created_at DESC
    LIMIT 1
) src
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'comment'
  AND _notification_photo_id(n.deep_link) IS NOT NULL
  AND src.author_firebase_uid IS NOT NULL
  AND src.author_firebase_uid IS DISTINCT FROM n.firebase_uid;

-- event_comments: same pattern for calendar event comments.
UPDATE notifications n
SET actor_firebase_uid = src.author_firebase_uid
FROM LATERAL (
    SELECT c.author_firebase_uid
    FROM event_comments c
    WHERE c.deleted_at IS NULL
      AND c.event_id = _notification_event_id(n.deep_link)
      AND c.created_at <= n.created_at + interval '2 seconds'
    ORDER BY c.created_at DESC
    LIMIT 1
) src
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'comment'
  AND _notification_event_id(n.deep_link) IS NOT NULL
  AND src.author_firebase_uid IS NOT NULL
  AND src.author_firebase_uid IS DISTINCT FROM n.firebase_uid;

-- photo_squishes: squish row at or before notification time.
UPDATE notifications n
SET actor_firebase_uid = src.firebase_uid
FROM LATERAL (
    SELECT s.firebase_uid
    FROM photo_squishes s
    WHERE s.photo_id = _notification_photo_id(n.deep_link)
      AND s.created_at <= n.created_at + interval '2 seconds'
    ORDER BY s.created_at DESC
    LIMIT 1
) src
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'squish'
  AND _notification_photo_id(n.deep_link) IS NOT NULL
  AND src.firebase_uid IS NOT NULL
  AND src.firebase_uid IS DISTINCT FROM n.firebase_uid;

-- New photo ready / gallery deep links: uploader on the photo row.
UPDATE notifications n
SET actor_firebase_uid = p.uploader_firebase_uid
FROM photos p
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'photo'
  AND p.id = _notification_photo_id(n.deep_link)
  AND p.uploader_firebase_uid IS NOT NULL
  AND p.uploader_firebase_uid IS DISTINCT FROM n.firebase_uid;

-- Calendar events: event_created activity row with matching event_id payload.
UPDATE notifications n
SET actor_firebase_uid = ae.actor_firebase_uid
FROM activity_events ae
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'event'
  AND _notification_event_id(n.deep_link) IS NOT NULL
  AND ae.baby_profile_id = n.baby_profile_id
  AND ae.event_type = 'event_created'
  AND ae.actor_firebase_uid IS NOT NULL
  AND (ae.payload ->> 'event_id') = _notification_event_id(n.deep_link)::text
  AND ae.created_at BETWEEN n.created_at - interval '30 seconds'
      AND n.created_at + interval '5 seconds';

-- Calendar events: RSVP actor (no activity row is written for RSVPs).
UPDATE notifications n
SET actor_firebase_uid = src.firebase_uid
FROM LATERAL (
    SELECT r.firebase_uid
    FROM event_rsvps r
    WHERE r.event_id = _notification_event_id(n.deep_link)
      AND r.updated_at <= n.created_at + interval '2 seconds'
    ORDER BY r.updated_at DESC
    LIMIT 1
) src
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'event'
  AND _notification_event_id(n.deep_link) IS NOT NULL
  AND src.firebase_uid IS NOT NULL
  AND src.firebase_uid IS DISTINCT FROM n.firebase_uid;

-- Invite accepted: new member on the baby (followers deep link).
UPDATE notifications n
SET actor_firebase_uid = src.firebase_uid
FROM LATERAL (
    SELECT m.firebase_uid
    FROM baby_memberships m
    WHERE m.baby_profile_id = _notification_baby_id_from_followers_link(n.deep_link)
      AND m.joined_via = 'invite'
      AND m.removed_at IS NULL
      AND m.firebase_uid IS DISTINCT FROM n.firebase_uid
      AND m.created_at BETWEEN n.created_at - interval '2 minutes'
          AND n.created_at + interval '5 seconds'
    ORDER BY m.created_at DESC
    LIMIT 1
) src
WHERE n.actor_firebase_uid IS NULL
  AND n.notification_type = 'generic'
  AND _notification_baby_id_from_followers_link(n.deep_link) IS NOT NULL
  AND src.firebase_uid IS NOT NULL;

-- Display name from app_users when we resolved an actor uid.
UPDATE notifications n
SET actor_display_name = NULLIF(TRIM(u.display_name), '')
FROM app_users u
WHERE n.actor_firebase_uid = u.firebase_uid
  AND n.actor_firebase_uid IS NOT NULL
  AND (n.actor_display_name IS NULL OR TRIM(n.actor_display_name) = '');

DROP FUNCTION IF EXISTS _notification_photo_id(TEXT);
DROP FUNCTION IF EXISTS _notification_event_id(TEXT);
DROP FUNCTION IF EXISTS _notification_baby_id_from_followers_link(TEXT);

INSERT INTO schema_migrations (version) VALUES ('037_notification_actor_backfill')
ON CONFLICT (version) DO NOTHING;
