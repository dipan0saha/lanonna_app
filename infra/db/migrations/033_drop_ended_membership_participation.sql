-- Drop presence rows left by people who are no longer current members
-- (FR-INV-009 / FR-INV-010). A participant counts only with an active
-- membership on that baby and an account that is not deleted.
-- Ending a membership now deletes the same rows. Comments, photos,
-- name suggestions, and registry claims are not touched.

DELETE FROM event_rsvps r
USING events e
WHERE r.event_id = e.id
  AND NOT EXISTS (
      SELECT 1
      FROM baby_memberships m
      JOIN app_users u ON u.firebase_uid = m.firebase_uid
      WHERE m.baby_profile_id = e.baby_profile_id
        AND m.firebase_uid = r.firebase_uid
        AND m.removed_at IS NULL
        AND u.deleted_at IS NULL
  );

DELETE FROM votes v
WHERE NOT EXISTS (
    SELECT 1
    FROM baby_memberships m
    JOIN app_users u ON u.firebase_uid = m.firebase_uid
    WHERE m.baby_profile_id = v.baby_profile_id
      AND m.firebase_uid = v.firebase_uid
      AND m.removed_at IS NULL
      AND u.deleted_at IS NULL
);

DELETE FROM name_suggestion_likes l
USING name_suggestions n
WHERE l.name_suggestion_id = n.id
  AND NOT EXISTS (
      SELECT 1
      FROM baby_memberships m
      JOIN app_users u ON u.firebase_uid = m.firebase_uid
      WHERE m.baby_profile_id = n.baby_profile_id
        AND m.firebase_uid = l.firebase_uid
        AND m.removed_at IS NULL
        AND u.deleted_at IS NULL
  );

DELETE FROM photo_squishes s
USING photos p
WHERE s.photo_id = p.id
  AND NOT EXISTS (
      SELECT 1
      FROM baby_memberships m
      JOIN app_users u ON u.firebase_uid = m.firebase_uid
      WHERE m.baby_profile_id = p.baby_profile_id
        AND m.firebase_uid = s.firebase_uid
        AND m.removed_at IS NULL
        AND u.deleted_at IS NULL
  );

DELETE FROM announcement_squishes s
USING birth_announcements a
WHERE s.announcement_id = a.id
  AND NOT EXISTS (
      SELECT 1
      FROM baby_memberships m
      JOIN app_users u ON u.firebase_uid = m.firebase_uid
      WHERE m.baby_profile_id = a.baby_profile_id
        AND m.firebase_uid = s.firebase_uid
        AND m.removed_at IS NULL
        AND u.deleted_at IS NULL
  );

INSERT INTO schema_migrations (version) VALUES ('033_drop_ended_membership_participation')
ON CONFLICT (version) DO NOTHING;
