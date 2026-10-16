-- Backfill the actor on legacy inbox rows (036 left them NULL) from structured
-- source rows only. No title/body text parsing: the fixed API title selects the
-- source table, the deep link supplies the source id.
--
-- Safety rules:
--   * only rows with actor_firebase_uid IS NULL are touched (idempotent);
--   * time-matched sources (comments, squishes, RSVPs, joins, purchases) must
--     fall in [notification - 2 min, notification + 5 s];
--   * a row is updated only when exactly ONE distinct candidate actor exists,
--     so ambiguity leaves it NULL instead of guessing;
--   * the recipient is never their own actor.

WITH n AS (
    SELECT
        id,
        firebase_uid AS recipient,
        baby_profile_id,
        title,
        created_at,
        substring(deep_link FROM '^/gallery/photo/([0-9a-fA-F-]{36})$')::uuid AS photo_id,
        substring(deep_link FROM '^/calendar/event/([0-9a-fA-F-]{36})$')::uuid AS event_id,
        substring(deep_link FROM '^/baby/([0-9a-fA-F-]{36})/followers$')::uuid AS joined_baby_id
    FROM notifications
    WHERE actor_firebase_uid IS NULL
),
candidates AS (
    SELECT n.id, n.recipient, c.author_firebase_uid AS actor
    FROM n JOIN photo_comments c ON c.photo_id = n.photo_id
    WHERE n.title = 'New comment'
      AND c.created_at BETWEEN n.created_at - interval '2 minutes'
                           AND n.created_at + interval '5 seconds'
    UNION ALL
    SELECT n.id, n.recipient, c.author_firebase_uid
    FROM n JOIN event_comments c ON c.event_id = n.event_id
    WHERE n.title = 'New comment'
      AND c.created_at BETWEEN n.created_at - interval '2 minutes'
                           AND n.created_at + interval '5 seconds'
    UNION ALL
    SELECT n.id, n.recipient, s.firebase_uid
    FROM n JOIN photo_squishes s ON s.photo_id = n.photo_id
    WHERE n.title = 'New squish'
      AND s.created_at BETWEEN n.created_at - interval '2 minutes'
                           AND n.created_at + interval '5 seconds'
    UNION ALL
    SELECT n.id, n.recipient, p.uploader_firebase_uid
    FROM n JOIN photos p ON p.id = n.photo_id
    WHERE n.title = 'New photo'
    UNION ALL
    SELECT n.id, n.recipient, e.created_by_firebase_uid
    FROM n JOIN events e ON e.id = n.event_id
    WHERE n.title = 'New event'
    UNION ALL
    SELECT n.id, n.recipient, r.firebase_uid
    FROM n JOIN event_rsvps r ON r.event_id = n.event_id
    WHERE n.title = 'New RSVP'
      AND r.updated_at BETWEEN n.created_at - interval '2 minutes'
                           AND n.created_at + interval '5 seconds'
    UNION ALL
    SELECT n.id, n.recipient, m.firebase_uid
    FROM n JOIN baby_memberships m ON m.baby_profile_id = n.joined_baby_id
    WHERE n.title = 'Invite accepted'
      AND m.joined_via = 'invite'
      AND m.created_at BETWEEN n.created_at - interval '2 minutes'
                           AND n.created_at + interval '5 seconds'
    UNION ALL
    SELECT n.id, n.recipient, ae.actor_firebase_uid
    FROM n JOIN activity_events ae ON ae.baby_profile_id = n.baby_profile_id
    WHERE n.title = 'Registry update'
      AND ae.event_type = 'registry_purchased'
      AND ae.created_at BETWEEN n.created_at - interval '2 minutes'
                            AND n.created_at + interval '5 seconds'
),
resolved AS (
    SELECT id, min(actor) AS actor
    FROM candidates
    WHERE actor IS NOT NULL AND actor IS DISTINCT FROM recipient
    GROUP BY id
    HAVING count(DISTINCT actor) = 1
)
UPDATE notifications t
SET actor_firebase_uid = u.firebase_uid,
    actor_display_name = NULLIF(TRIM(u.display_name), '')
FROM resolved r
JOIN app_users u ON u.firebase_uid = r.actor
WHERE t.id = r.id
  AND t.actor_firebase_uid IS NULL;

INSERT INTO schema_migrations (version) VALUES ('037_notification_actor_backfill')
ON CONFLICT (version) DO NOTHING;
