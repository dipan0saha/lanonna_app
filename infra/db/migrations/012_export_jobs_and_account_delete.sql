-- Baby data export jobs (NFR-DATA-001) and account soft-delete marker.

CREATE TABLE IF NOT EXISTS baby_data_export_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_profile_id UUID NOT NULL REFERENCES baby_profiles (id) ON DELETE CASCADE,
    requested_by_firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'ready', 'failed')),
    object_path TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_baby_data_export_jobs_baby_created
    ON baby_data_export_jobs (baby_profile_id, created_at DESC);

ALTER TABLE app_users
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

INSERT INTO schema_migrations (version) VALUES ('012_export_jobs_and_account_delete')
ON CONFLICT (version) DO NOTHING;
