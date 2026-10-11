-- Export job stale-running reclaim (M-11).

ALTER TABLE baby_data_export_jobs
    ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;

INSERT INTO schema_migrations (version) VALUES ('026_export_job_started_at')
ON CONFLICT (version) DO NOTHING;
