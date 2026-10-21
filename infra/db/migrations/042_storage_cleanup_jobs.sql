-- Async GCS cleanup after account or baby profile deletion (FR-SET-005 / Play data deletion).

CREATE TABLE IF NOT EXISTS storage_cleanup_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind TEXT NOT NULL
        CHECK (kind IN ('account_delete', 'baby_profile_delete')),
    firebase_uid TEXT NOT NULL REFERENCES app_users (firebase_uid),
    baby_profile_ids UUID[] NOT NULL DEFAULT '{}',
    detached_objects JSONB NOT NULL DEFAULT '[]',
    export_object_paths TEXT[] NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    objects_deleted_count INT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_storage_cleanup_jobs_status_created
    ON storage_cleanup_jobs (status, created_at);

CREATE UNIQUE INDEX IF NOT EXISTS idx_storage_cleanup_jobs_account_inflight
    ON storage_cleanup_jobs (firebase_uid)
    WHERE kind = 'account_delete' AND status IN ('pending', 'running');

INSERT INTO schema_migrations (version) VALUES ('042_storage_cleanup_jobs')
ON CONFLICT (version) DO NOTHING;
