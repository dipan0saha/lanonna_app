-- Referencing-side FK indexes for photo lifecycle, account delete, and baby hard-delete.
-- See docs/engineering/rca/fk-indexes-photo-references.md.
--
-- Plain CREATE INDEX (not CONCURRENTLY): apply_migrations.py runs every file in
-- one transaction (same as 045/050). lock_timeout fails the migration instead of
-- queueing behind a long-held lock. Idempotent via IF NOT EXISTS.
SET LOCAL lock_timeout = '5s';

-- delete_unreferenced_event_cover / _stale_cover_ids NOT EXISTS; ON DELETE SET NULL from photos.
CREATE INDEX IF NOT EXISTS idx_events_cover_photo_id
    ON events (cover_photo_id)
    WHERE cover_photo_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_birth_announcements_photo_id
    ON birth_announcements (photo_id)
    WHERE photo_id IS NOT NULL;

-- Account delete: purge_authored_photos_on_shared_babies.
CREATE INDEX IF NOT EXISTS idx_photos_uploader_firebase_uid
    ON photos (uploader_firebase_uid);

-- Account delete: collect_and_delete_export_jobs (requested_by path).
CREATE INDEX IF NOT EXISTS idx_baby_data_export_jobs_requested_by
    ON baby_data_export_jobs (requested_by_firebase_uid);

-- Account delete: revoke pending invites sent by the user.
CREATE INDEX IF NOT EXISTS idx_invitations_inviter_firebase_uid
    ON invitations (inviter_firebase_uid);

-- Baby hard-delete: notifications.baby_profile_id ON DELETE CASCADE (043).
CREATE INDEX IF NOT EXISTS idx_notifications_baby_profile_id
    ON notifications (baby_profile_id)
    WHERE baby_profile_id IS NOT NULL;

INSERT INTO schema_migrations (version) VALUES ('051_fk_reference_indexes')
ON CONFLICT (version) DO NOTHING;
