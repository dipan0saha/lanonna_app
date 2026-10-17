-- Unnamed babies store NULL, never a placeholder (open gap L-36).
--
-- Until this release the app filled a missing name with its localized default
-- "Baby" before POST /v1/babies (the API required a name), so the display
-- fallback was persisted as data and later read back as if the owner typed it.
-- The name is now optional end to end and the app applies its fallback at
-- display time only.
--
-- Normalization criterion: the app's only locale has ever been English, and
-- the fallback was sent verbatim after trimming, so a name stored as exactly
-- 'Baby' is the persisted default. Blank names are normalized too. A baby an
-- owner genuinely named "Baby" is indistinguishable from the default; it
-- still displays as "Baby" (the localized fallback) and the owner can type the
-- name again. Matching is exact and case-sensitive ('baby', 'Baby Parker'
-- and 'Baby ' with other text are left alone).
--
-- Gender: NULL and 'unknown' meant the same thing; 'unknown' is now the only
-- representation (NOT NULL DEFAULT 'unknown').
--
-- Forward-only; re-running is a no-op.

ALTER TABLE baby_profiles ALTER COLUMN name DROP NOT NULL;

-- Display params snapshotted from a placeholder name (arrival activity rows and
-- invite-accepted / baby-arrived inbox rows). Only rows of babies whose stored
-- name is the placeholder are touched, before that name is cleared below.
UPDATE activity_events a
SET params = a.params - 'baby_name'
FROM baby_profiles b
WHERE b.id = a.baby_profile_id
  AND a.params->>'baby_name' = 'Baby'
  AND b.name = 'Baby';

UPDATE notifications n
SET params = n.params - 'baby_name'
FROM baby_profiles b
WHERE b.id = n.baby_profile_id
  AND n.params->>'baby_name' = 'Baby'
  AND b.name = 'Baby';

UPDATE baby_profiles
SET name = NULL
WHERE name = 'Baby' OR btrim(name) = '';

UPDATE baby_profiles SET gender = 'unknown' WHERE gender IS NULL;

ALTER TABLE baby_profiles
    ALTER COLUMN gender SET DEFAULT 'unknown',
    ALTER COLUMN gender SET NOT NULL;

-- A stored name is real text; "no name" is NULL only.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'baby_profiles_name_not_blank'
    ) THEN
        ALTER TABLE baby_profiles
            ADD CONSTRAINT baby_profiles_name_not_blank
            CHECK (name IS NULL OR btrim(name) <> '');
    END IF;
END $$;

INSERT INTO schema_migrations (version) VALUES ('039_baby_name_nullable_gender_not_null')
ON CONFLICT (version) DO NOTHING;
