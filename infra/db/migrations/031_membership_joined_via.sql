-- Distinguish babies a user created from owner memberships accepted by invite (#31).
-- Migration 024 stamped created_by_firebase_uid from the earliest *active* owner,
-- so a co-owner could be recorded as the creator after the original owner left.

ALTER TABLE baby_memberships
    ADD COLUMN IF NOT EXISTS joined_via TEXT;

UPDATE baby_memberships
SET joined_via = 'invite'
WHERE joined_via IS NULL;

UPDATE baby_memberships m
SET joined_via = 'created'
FROM (
    SELECT DISTINCT ON (baby_profile_id)
        id
    FROM baby_memberships
    WHERE role = 'owner'
    ORDER BY baby_profile_id, created_at ASC, id ASC
) first
WHERE m.id = first.id;

UPDATE baby_profiles b
SET created_by_firebase_uid = sub.firebase_uid
FROM (
    SELECT DISTINCT ON (baby_profile_id)
        baby_profile_id,
        firebase_uid
    FROM baby_memberships
    WHERE role = 'owner'
    ORDER BY baby_profile_id, created_at ASC, id ASC
) sub
WHERE b.id = sub.baby_profile_id
  AND b.deleted_at IS NULL
  AND b.created_by_firebase_uid IS DISTINCT FROM sub.firebase_uid;

ALTER TABLE baby_memberships
    ALTER COLUMN joined_via SET DEFAULT 'invite';

ALTER TABLE baby_memberships
    ALTER COLUMN joined_via SET NOT NULL;

ALTER TABLE baby_memberships
    DROP CONSTRAINT IF EXISTS baby_memberships_joined_via_check;

ALTER TABLE baby_memberships
    ADD CONSTRAINT baby_memberships_joined_via_check
    CHECK (joined_via IN ('created', 'invite'));

INSERT INTO schema_migrations (version) VALUES ('031_membership_joined_via')
ON CONFLICT (version) DO NOTHING;
