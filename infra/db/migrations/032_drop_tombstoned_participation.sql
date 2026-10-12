-- Drop presence rows already left behind by tombstoned accounts (FR-SET-005).
-- RSVPs, votes, name loves, and squishes are participation, not authored content.
-- New deletions remove the same rows in purge_participation.

DELETE FROM event_rsvps r
USING app_users u
WHERE r.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

DELETE FROM votes v
USING app_users u
WHERE v.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

DELETE FROM name_suggestion_likes l
USING app_users u
WHERE l.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

DELETE FROM photo_squishes s
USING app_users u
WHERE s.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

DELETE FROM announcement_squishes s
USING app_users u
WHERE s.firebase_uid = u.firebase_uid
  AND u.deleted_at IS NOT NULL;

INSERT INTO schema_migrations (version) VALUES ('032_drop_tombstoned_participation')
ON CONFLICT (version) DO NOTHING;
