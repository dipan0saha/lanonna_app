-- Referencing-side indexes for parent deletes and the account-delete path.
-- See docs/engineering/rca/fk-indexes-photo-references.md.
--
-- Postgres probes every referencing table on each parent DELETE, whatever the
-- ON DELETE action. photos, events and baby_profiles rows are hard-deleted, so
-- every FK to them needs an index whose leading column is the FK column and
-- whose predicate (if partial) is implied by "fk = $1" (only "fk IS NOT NULL").
-- app_users rows are tombstoned, never deleted, so FKs to app_users are indexed
-- only where account delete queries them by uid.
--
-- Plain CREATE INDEX (not CONCURRENTLY): apply_migrations.py runs every file in
-- one transaction (same as 045/050). lock_timeout fails the migration instead of
-- queueing behind a long-held lock. Idempotent via IF [NOT] EXISTS.
SET LOCAL lock_timeout = '5s';

-- photos parent: delete_unreferenced_event_cover / _stale_cover_ids NOT EXISTS
-- probes and the ON DELETE SET NULL check on every photo delete. Nullable
-- columns, so a "IS NOT NULL" partial still serves the FK probe.
CREATE INDEX IF NOT EXISTS idx_events_cover_photo_id
    ON events (cover_photo_id)
    WHERE cover_photo_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_birth_announcements_photo_id
    ON birth_announcements (photo_id)
    WHERE photo_id IS NOT NULL;

-- photos / events parents: ON DELETE CASCADE to comments. The existing
-- (photo_id|event_id, created_at) indexes are partial on deleted_at IS NULL,
-- which the FK probe cannot use (soft-deleted comments still reference).
CREATE INDEX IF NOT EXISTS idx_photo_comments_photo_id
    ON photo_comments (photo_id);

CREATE INDEX IF NOT EXISTS idx_event_comments_event_id
    ON event_comments (event_id);

-- baby_profiles parent (baby hard-delete, 043): ON DELETE CASCADE to inbox rows.
CREATE INDEX IF NOT EXISTS idx_notifications_baby_profile_id
    ON notifications (baby_profile_id)
    WHERE baby_profile_id IS NOT NULL;

-- Account delete (delete_account_rows), one index per "WHERE <uid col> = $1":
-- purge_authored_photos_on_shared_babies
CREATE INDEX IF NOT EXISTS idx_photos_uploader_firebase_uid
    ON photos (uploader_firebase_uid);

-- collect_and_delete_export_jobs (requested_by path)
CREATE INDEX IF NOT EXISTS idx_baby_data_export_jobs_requested_by
    ON baby_data_export_jobs (requested_by_firebase_uid);

-- revoke pending invites the user sent
CREATE INDEX IF NOT EXISTS idx_invitations_inviter_firebase_uid
    ON invitations (inviter_firebase_uid);

-- purge_personal_user_data: settled invites addressed to the user's email
CREATE INDEX IF NOT EXISTS idx_invitations_invitee_email_lower
    ON invitations (lower(invitee_email));

-- purge_personal_user_data: other people's inbox rows naming the user
CREATE INDEX IF NOT EXISTS idx_notifications_actor_firebase_uid
    ON notifications (actor_firebase_uid)
    WHERE actor_firebase_uid IS NOT NULL;

-- purge_personal_user_data: banner dismissals (PK leads with announcement_id)
CREATE INDEX IF NOT EXISTS idx_announcement_dismissals_firebase_uid
    ON announcement_dismissals (firebase_uid);

-- purge_personal_user_data: all biometric keys, revoked ones included (the
-- unique index is partial on revoked_at IS NULL)
CREATE INDEX IF NOT EXISTS idx_biometric_credentials_firebase_uid
    ON biometric_credentials (firebase_uid);

-- purge_participation: votes (unique key leads with baby_profile_id)
CREATE INDEX IF NOT EXISTS idx_votes_firebase_uid
    ON votes (firebase_uid);

-- purge_participation: event_rsvps (PK leads with event_id). (firebase_uid,
-- status) also serves the engagement count "firebase_uid = $1 AND status =
-- 'going'", so it supersedes the 010 partial on the same leading column.
CREATE INDEX IF NOT EXISTS idx_event_rsvps_firebase_uid_status
    ON event_rsvps (firebase_uid, status);

DROP INDEX IF EXISTS idx_event_rsvps_firebase_uid_going;

-- rerender_activity_summaries: "actor_firebase_uid = $1 OR
-- payload->>'target_firebase_uid' = $1" (BitmapOr over both).
CREATE INDEX IF NOT EXISTS idx_activity_events_actor_firebase_uid
    ON activity_events (actor_firebase_uid)
    WHERE actor_firebase_uid IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_activity_events_target_firebase_uid
    ON activity_events ((payload->>'target_firebase_uid'))
    WHERE payload->>'target_firebase_uid' IS NOT NULL;

INSERT INTO schema_migrations (version) VALUES ('051_fk_reference_indexes')
ON CONFLICT (version) DO NOTHING;
