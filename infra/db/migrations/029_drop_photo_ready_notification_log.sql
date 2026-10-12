-- Legacy photo-ready idempotency table (replaced by fan-out dedupe_key + worker_delivery_log).

DROP TABLE IF EXISTS photo_ready_notification_log;

INSERT INTO schema_migrations (version) VALUES ('029_drop_photo_ready_notification_log')
ON CONFLICT (version) DO NOTHING;
