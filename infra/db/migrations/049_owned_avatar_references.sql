-- 049: avatars may only name an object directly under their owner's upload
-- prefix (#415). Before #415 the API stored any string the app sent, so a row
-- could point at another account's object or at an outside URL.
--   1. Legacy GCS URLs (public or signed) become bare object paths.
--   2. Anything still not under the owner's prefix is cleared (reads as no
--      avatar; the owner can pick a photo again).
--   3. CHECK constraints keep every writer to that rule from now on.
-- Safe to apply before or after the #415 API (that API already writes only
-- owned paths and ignores unowned ones on read).

SET LOCAL lock_timeout = '5s';

UPDATE app_users
SET avatar_url = substring(
    avatar_url
    FROM '^https://(?:storage\.googleapis\.com/[^/?#]+|[^/?#]+\.storage\.googleapis\.com)/([^?#]+)'
)
WHERE avatar_url ~ '^https://(?:storage\.googleapis\.com/[^/?#]+|[^/?#]+\.storage\.googleapis\.com)/[^?#]+';

UPDATE baby_profiles
SET avatar_url = substring(
    avatar_url
    FROM '^https://(?:storage\.googleapis\.com/[^/?#]+|[^/?#]+\.storage\.googleapis\.com)/([^?#]+)'
)
WHERE avatar_url ~ '^https://(?:storage\.googleapis\.com/[^/?#]+|[^/?#]+\.storage\.googleapis\.com)/[^?#]+';

-- Owned = '<prefix><name>' where name is non-empty, has no '/', and is not
-- '.' or '..' (the shape /v1/uploads/display/signed-url mints).
UPDATE app_users
SET avatar_url = NULL
WHERE avatar_url IS NOT NULL
  AND NOT (
        starts_with(avatar_url, 'avatars/users/' || firebase_uid || '/')
        AND strpos(substr(avatar_url, length('avatars/users/' || firebase_uid || '/') + 1), '/') = 0
        AND substr(avatar_url, length('avatars/users/' || firebase_uid || '/') + 1) NOT IN ('', '.', '..')
  );

UPDATE baby_profiles
SET avatar_url = NULL
WHERE avatar_url IS NOT NULL
  AND NOT (
        starts_with(avatar_url, 'avatars/babies/' || id::text || '/')
        AND strpos(substr(avatar_url, length('avatars/babies/' || id::text || '/') + 1), '/') = 0
        AND substr(avatar_url, length('avatars/babies/' || id::text || '/') + 1) NOT IN ('', '.', '..')
  );

ALTER TABLE app_users
    DROP CONSTRAINT IF EXISTS app_users_avatar_url_owned,
    ADD CONSTRAINT app_users_avatar_url_owned CHECK (
        avatar_url IS NULL
        OR (
        starts_with(avatar_url, 'avatars/users/' || firebase_uid || '/')
        AND strpos(substr(avatar_url, length('avatars/users/' || firebase_uid || '/') + 1), '/') = 0
        AND substr(avatar_url, length('avatars/users/' || firebase_uid || '/') + 1) NOT IN ('', '.', '..')
        )
    );

ALTER TABLE baby_profiles
    DROP CONSTRAINT IF EXISTS baby_profiles_avatar_url_owned,
    ADD CONSTRAINT baby_profiles_avatar_url_owned CHECK (
        avatar_url IS NULL
        OR (
        starts_with(avatar_url, 'avatars/babies/' || id::text || '/')
        AND strpos(substr(avatar_url, length('avatars/babies/' || id::text || '/') + 1), '/') = 0
        AND substr(avatar_url, length('avatars/babies/' || id::text || '/') + 1) NOT IN ('', '.', '..')
        )
    );

INSERT INTO schema_migrations (version) VALUES ('049_owned_avatar_references')
ON CONFLICT (version) DO NOTHING;
