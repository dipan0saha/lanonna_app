-- Track baby profile creator for owner-onboarding gating (#31).

ALTER TABLE baby_profiles
    ADD COLUMN IF NOT EXISTS created_by_firebase_uid TEXT
        REFERENCES app_users (firebase_uid);

UPDATE baby_profiles b
SET created_by_firebase_uid = sub.creator_uid
FROM (
    SELECT DISTINCT ON (m.baby_profile_id)
        m.baby_profile_id,
        m.firebase_uid AS creator_uid
    FROM baby_memberships m
    WHERE m.role = 'owner'
      AND m.removed_at IS NULL
    ORDER BY m.baby_profile_id, m.created_at ASC
) sub
WHERE b.id = sub.baby_profile_id
  AND b.created_by_firebase_uid IS NULL
  AND b.deleted_at IS NULL;
