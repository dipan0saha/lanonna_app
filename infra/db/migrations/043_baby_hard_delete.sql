-- Hard-delete baby profiles and dependents (ON DELETE CASCADE). Backfill soft-deleted babies.

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tc.table_schema, tc.table_name, tc.constraint_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_schema = kcu.constraint_schema
     AND tc.constraint_name = kcu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
      AND kcu.column_name = 'baby_profile_id'
      AND tc.table_name NOT IN ('birth_announcements', 'baby_data_export_jobs')
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I DROP CONSTRAINT %I',
      r.table_schema,
      r.table_name,
      r.constraint_name
    );
    EXECUTE format(
      'ALTER TABLE %I.%I ADD CONSTRAINT %I '
      'FOREIGN KEY (baby_profile_id) REFERENCES baby_profiles (id) ON DELETE CASCADE',
      r.table_schema,
      r.table_name,
      r.constraint_name
    );
  END LOOP;
END $$;

-- Backfill: enqueue GCS cleanup for rows that were only soft-deleted, then remove them.
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
                ORDER BY m.created_at ASC, m.id ASC
                LIMIT 1
            )
        ) AS firebase_uid
    FROM baby_profiles b
    WHERE b.deleted_at IS NOT NULL
),
export_paths AS (
    SELECT
        j.baby_profile_id,
        array_agg(j.object_path) FILTER (WHERE j.object_path IS NOT NULL) AS paths
    FROM baby_data_export_jobs j
    WHERE j.baby_profile_id IN (SELECT id FROM doomed)
    GROUP BY j.baby_profile_id
),
photo_objects AS (
    SELECT
        p.baby_profile_id,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'display_path', p.display_path,
                    'thumb_path', p.thumb_path
                )
            ),
            '[]'::jsonb
        ) AS detached
    FROM photos p
    WHERE p.baby_profile_id IN (SELECT id FROM doomed)
    GROUP BY p.baby_profile_id
)
INSERT INTO storage_cleanup_jobs (
    kind,
    firebase_uid,
    baby_profile_ids,
    detached_objects,
    export_object_paths,
    status
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
