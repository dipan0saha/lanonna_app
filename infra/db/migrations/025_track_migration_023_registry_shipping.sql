-- Record 023 for databases that ran 023_registry_shipping_structured.sql before it
-- inserted into schema_migrations. Legacy registry_shipping_address was dropped in 023;
-- no backfill into structured columns is possible after that drop.

INSERT INTO schema_migrations (version) VALUES ('023_registry_shipping_structured')
ON CONFLICT (version) DO NOTHING;

INSERT INTO schema_migrations (version) VALUES ('025_track_migration_023_registry_shipping')
ON CONFLICT (version) DO NOTHING;
