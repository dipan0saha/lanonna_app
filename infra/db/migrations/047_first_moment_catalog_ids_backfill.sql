-- 047: link first-moment seeds made before #412 to their catalog rows, so the
-- AI suggestion lists stop offering what onboarding already added.
-- Safe before or after the API deploy; idempotent. Titles are left as stored
-- (owners may have edited them). Rows whose baby already has the catalog id
-- keep their old value, so the per-baby unique indexes never conflict.

SET LOCAL lock_timeout = '5s';

-- Born preset "first_checkup" is the catalog's "first_pediatric_visit".
UPDATE events e
SET catalog_suggestion_id = 'first_pediatric_visit'
WHERE e.catalog_suggestion_id = 'first_checkup'
  AND NOT EXISTS (
      SELECT 1
      FROM events other
      WHERE other.baby_profile_id = e.baby_profile_id
        AND other.catalog_suggestion_id = 'first_pediatric_visit'
  );

-- Registry seeds were stored by name only. One row per baby and catalog id.
WITH preset_names (name, catalog_suggestion_id) AS (
    VALUES
        ('Swaddles', 'swaddle_blankets'),
        ('Crib', 'crib_mattress'),
        ('Diapers', 'diaper_stockpile')
),
candidates AS (
    SELECT DISTINCT ON (r.baby_profile_id, p.catalog_suggestion_id)
        r.id, p.catalog_suggestion_id
    FROM registry_items r
    JOIN preset_names p ON p.name = r.name
    WHERE r.catalog_suggestion_id IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM registry_items other
          WHERE other.baby_profile_id = r.baby_profile_id
            AND other.catalog_suggestion_id = p.catalog_suggestion_id
      )
    ORDER BY r.baby_profile_id, p.catalog_suggestion_id, r.created_at, r.id
)
UPDATE registry_items r
SET catalog_suggestion_id = c.catalog_suggestion_id
FROM candidates c
WHERE r.id = c.id;

INSERT INTO schema_migrations (version) VALUES ('047_first_moment_catalog_ids_backfill')
ON CONFLICT (version) DO NOTHING;
