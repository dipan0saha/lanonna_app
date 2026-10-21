-- 043: deleting a baby profile hard-deletes every row scoped to it (owner decision
-- 2026-10-21). Every FK to baby_profiles becomes ON DELETE CASCADE; children of
-- those rows (comments, RSVPs, squishes, likes, purchases, tags) already cascade.
-- birth_announcements, baby_data_export_jobs and photo_baby_tags already cascade.
-- storage_cleanup_jobs holds baby ids in an array (no FK), so its rows survive.
--
-- Lock-light: each FK is re-added NOT VALID (no scan under the strong lock) and then
-- validated. lock_timeout makes a busy table fail the migration instead of queueing
-- traffic behind it. Re-runnable: constraints are dropped IF EXISTS and re-added, and
-- the backfill only touches rows that are still soft-deleted.

SET LOCAL lock_timeout = '5s';

ALTER TABLE activity_events
    DROP CONSTRAINT IF EXISTS activity_events_baby_profile_id_fkey,
    ADD CONSTRAINT activity_events_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE activity_events VALIDATE CONSTRAINT activity_events_baby_profile_id_fkey;

ALTER TABLE baby_memberships
    DROP CONSTRAINT IF EXISTS baby_memberships_baby_profile_id_fkey,
    ADD CONSTRAINT baby_memberships_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE baby_memberships VALIDATE CONSTRAINT baby_memberships_baby_profile_id_fkey;

ALTER TABLE events
    DROP CONSTRAINT IF EXISTS events_baby_profile_id_fkey,
    ADD CONSTRAINT events_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE events VALIDATE CONSTRAINT events_baby_profile_id_fkey;

ALTER TABLE invitations
    DROP CONSTRAINT IF EXISTS invitations_baby_profile_id_fkey,
    ADD CONSTRAINT invitations_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE invitations VALIDATE CONSTRAINT invitations_baby_profile_id_fkey;

ALTER TABLE name_suggestions
    DROP CONSTRAINT IF EXISTS name_suggestions_baby_profile_id_fkey,
    ADD CONSTRAINT name_suggestions_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE name_suggestions VALIDATE CONSTRAINT name_suggestions_baby_profile_id_fkey;

ALTER TABLE notifications
    DROP CONSTRAINT IF EXISTS notifications_baby_profile_id_fkey,
    ADD CONSTRAINT notifications_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE notifications VALIDATE CONSTRAINT notifications_baby_profile_id_fkey;

ALTER TABLE photos
    DROP CONSTRAINT IF EXISTS photos_baby_profile_id_fkey,
    ADD CONSTRAINT photos_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE photos VALIDATE CONSTRAINT photos_baby_profile_id_fkey;

ALTER TABLE registry_items
    DROP CONSTRAINT IF EXISTS registry_items_baby_profile_id_fkey,
    ADD CONSTRAINT registry_items_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE registry_items VALIDATE CONSTRAINT registry_items_baby_profile_id_fkey;

ALTER TABLE votes
    DROP CONSTRAINT IF EXISTS votes_baby_profile_id_fkey,
    ADD CONSTRAINT votes_baby_profile_id_fkey
        FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE NOT VALID;
ALTER TABLE votes VALIDATE CONSTRAINT votes_baby_profile_id_fkey;

-- Guard: any FK to baby_profiles that is not CASCADE would make baby delete fail.
DO $$
DECLARE
    leftover TEXT;
BEGIN
    SELECT string_agg(conrelid::regclass::text || '.' || conname, ', ')
    INTO leftover
    FROM pg_constraint
    WHERE contype = 'f'
      AND confrelid = 'baby_profiles'::regclass
      AND confdeltype <> 'c';
    IF leftover IS NOT NULL THEN
        RAISE EXCEPTION 'baby_profiles FKs without ON DELETE CASCADE: %', leftover;
    END IF;
END $$;

-- Backfill: babies soft-deleted before this migration. One baby_profile_delete
-- cleanup job per baby carries its photo and export paths (rows are about to go);
-- the worker sweep runs pending jobs older than 10 minutes, so no publish is needed.
WITH doomed AS (
    SELECT
        b.id,
        COALESCE(
            b.created_by_firebase_uid,
            (
                SELECT m.firebase_uid
                FROM baby_memberships m
                WHERE m.baby_profile_id = b.id
                  AND m.role = 'owner'
                ORDER BY m.created_at, m.id
                LIMIT 1
            )
        ) AS firebase_uid
    FROM baby_profiles b
    WHERE b.deleted_at IS NOT NULL
),
photo_objects AS (
    SELECT
        p.baby_profile_id,
        jsonb_agg(
            jsonb_build_object('display_path', p.display_path, 'thumb_path', p.thumb_path)
        ) AS detached
    FROM photos p
    WHERE p.baby_profile_id IN (SELECT id FROM doomed)
    GROUP BY p.baby_profile_id
),
export_paths AS (
    SELECT
        j.baby_profile_id,
        array_agg(j.object_path) FILTER (WHERE j.object_path IS NOT NULL) AS paths
    FROM baby_data_export_jobs j
    WHERE j.baby_profile_id IN (SELECT id FROM doomed)
    GROUP BY j.baby_profile_id
)
INSERT INTO storage_cleanup_jobs (
    kind, firebase_uid, baby_profile_ids, detached_objects, export_object_paths, status
)
SELECT
    'baby_profile_delete',
    d.firebase_uid,
    ARRAY[d.id],
    COALESCE(po.detached, '[]'::jsonb),
    COALESCE(ep.paths, '{}'::text[]),
    'pending'
FROM doomed d
LEFT JOIN photo_objects po ON po.baby_profile_id = d.id
LEFT JOIN export_paths ep ON ep.baby_profile_id = d.id
WHERE d.firebase_uid IS NOT NULL;

DELETE FROM baby_profiles WHERE deleted_at IS NOT NULL;

INSERT INTO schema_migrations (version) VALUES ('043_baby_hard_delete')
ON CONFLICT (version) DO NOTHING;
