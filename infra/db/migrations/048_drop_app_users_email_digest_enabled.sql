-- 048: the weekly digest is push-only (FR-NOTIF-002, #411); nothing sends email
-- digests, so the email opt-in column is unused.
-- Apply after the API that no longer reads it is deployed (contract step).

SET LOCAL lock_timeout = '5s';

ALTER TABLE app_users DROP COLUMN IF EXISTS email_digest_enabled;

INSERT INTO schema_migrations (version) VALUES ('048_drop_app_users_email_digest_enabled')
ON CONFLICT (version) DO NOTHING;
