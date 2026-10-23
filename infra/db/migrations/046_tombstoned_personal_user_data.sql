-- 046: accounts deleted before #364 kept personal rows, because app_users is
-- tombstoned (never deleted) so ON DELETE CASCADE never fired. Apply the
-- rules of lanonna_api.repositories.account_delete_user_data to every
-- tombstoned account (FR-SET-005). Idempotent: every statement only matches
-- rows that still hold personal data. Invitations they received cannot be
-- matched here (the tombstone already cleared the email).

SET LOCAL lock_timeout = '5s';

DELETE FROM notifications n
USING app_users u
WHERE u.deleted_at IS NOT NULL
  AND (n.firebase_uid = u.firebase_uid OR n.actor_firebase_uid = u.firebase_uid);

DELETE FROM device_tokens t
USING app_users u
WHERE t.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

DELETE FROM announcement_dismissals d
USING app_users u
WHERE d.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

DELETE FROM biometric_credentials b
USING app_users u
WHERE b.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

UPDATE app_users
SET display_name = 'Deleted user',
    email = NULL,
    avatar_url = NULL,
    phone = NULL,
    birth_date = NULL,
    country_code = NULL,
    postal_code = NULL,
    last_seen_at = NULL,
    biometric_unlock_enabled = false
WHERE deleted_at IS NOT NULL
  AND (display_name IS DISTINCT FROM 'Deleted user'
       OR email IS NOT NULL OR avatar_url IS NOT NULL OR phone IS NOT NULL
       OR birth_date IS NOT NULL OR country_code IS NOT NULL
       OR postal_code IS NOT NULL OR last_seen_at IS NOT NULL
       OR biometric_unlock_enabled);

-- Feed summaries that embedded a deleted person's old name. Same sentences as
-- lanonna_activity_copy.activity_summary at 046 (frozen; the Postgres test
-- test_migration_046_summary_matches_activity_copy checks parity).
WITH named AS (
    SELECT e.id, e.event_type, e.params,
           COALESCE(NULLIF(TRIM(a.display_name), ''), 'Someone') AS actor,
           COALESCE(NULLIF(TRIM(t.display_name), ''), 'a member') AS target
    FROM activity_events e
    LEFT JOIN app_users a ON a.firebase_uid = e.actor_firebase_uid
    LEFT JOIN app_users t ON t.firebase_uid = e.payload->>'target_firebase_uid'
    WHERE a.deleted_at IS NOT NULL OR t.deleted_at IS NOT NULL
),
rendered AS (
    SELECT id,
           CASE event_type
               WHEN 'photo_shared' THEN actor || ' shared ' || caption
               WHEN 'photo_squish' THEN actor || ' squished ' || caption
               WHEN 'photo_comment' THEN actor || ' commented on ' || caption
               WHEN 'registry_item_added' THEN actor || ' added ' || item || ' to the registry'
               WHEN 'registry_purchased' THEN actor || ' marked ' || item || ' as purchased'
               WHEN 'registry_claimed' THEN 'Someone is buying ' || item
               WHEN 'event_created' THEN actor || ' added '
                   || COALESCE('"' || NULLIF(TRIM(params->>'event_title'), '') || '"', 'an event')
                   || ' to the calendar'
               WHEN 'name_suggested' THEN actor || ' suggested the name '
                   || COALESCE('"' || NULLIF(TRIM(params->>'suggested_name'), '') || '"', 'a name')
               WHEN 'gender_vote_cast' THEN actor || ' guessed '
                   || COALESCE(NULLIF(params->>'gender', ''), 'the gender')
               WHEN 'baby_arrived' THEN COALESCE(NULLIF(params->>'baby_name', ''), 'The baby')
                   || ' has arrived!'
               WHEN 'member_removed' THEN actor || ' removed ' || target || ' from the family'
               WHEN 'member_left' THEN actor || ' left the family'
               ELSE actor || ': ' || event_type
           END AS summary
    FROM (
        SELECT named.*,
               COALESCE('"' || NULLIF(TRIM(params->>'caption'), '') || '"', 'a photo') AS caption,
               COALESCE('"' || NULLIF(TRIM(params->>'item_name'), '') || '"', 'an item') AS item
        FROM named
    ) n
)
UPDATE activity_events e
SET summary = r.summary
FROM rendered r
WHERE e.id = r.id
  AND e.summary IS DISTINCT FROM r.summary;

INSERT INTO schema_migrations (version) VALUES ('046_tombstoned_personal_user_data')
ON CONFLICT (version) DO NOTHING;
