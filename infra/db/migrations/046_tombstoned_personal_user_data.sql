-- 046: tombstoned accounts keep app_users rows, so ON DELETE CASCADE on
-- notifications / device_tokens / biometric_credentials never fired. Mirror
-- delete_account_rows purge for accounts already deleted (FR-SET-005).

DELETE FROM notifications n
USING app_users u
WHERE n.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

UPDATE notifications n
SET actor_firebase_uid = NULL,
    actor_display_name = NULL
FROM app_users u
WHERE n.actor_firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

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

INSERT INTO schema_migrations (version) VALUES ('046_tombstoned_personal_user_data')
ON CONFLICT (version) DO NOTHING;
