-- Worker idempotency: invite email, notification delivery, photo-ready notify fan-out.

ALTER TABLE invitations
    ADD COLUMN IF NOT EXISTS email_sent_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS worker_delivery_log (
    delivery_key TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS photo_ready_notification_log (
    photo_id UUID NOT NULL REFERENCES photos (id) ON DELETE CASCADE,
    object_generation BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (photo_id, object_generation)
);

INSERT INTO schema_migrations (version) VALUES ('021_worker_idempotency')
ON CONFLICT (version) DO NOTHING;
