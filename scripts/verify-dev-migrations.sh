#!/usr/bin/env bash
# Verify dev Cloud SQL has migrations 001–023 applied (when proxy + PGPASSWORD are set).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIG_DIR="${ROOT}/infra/db/migrations"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5433}"
DB_USER="${DB_USER:-lanonna_app}"
DB_NAME="${DB_NAME:-lanonna}"

expected="$(find "${MIG_DIR}" -maxdepth 1 -name '*.sql' | wc -l | tr -d ' ')"
echo "Expected migration files: ${expected}"

export DB_PASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"

if [[ -z "${DB_PASSWORD}" ]]; then
  echo "SKIP: set PGPASSWORD or DB_PASSWORD and run Cloud SQL proxy on port ${DB_PORT} to verify live schema."
  exit 0
fi

export PGPASSWORD="${DB_PASSWORD}"

count="$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  'SELECT count(*) FROM schema_migrations;' 2>/dev/null || true)"

if [[ -z "${count}" ]]; then
  echo "SKIP: could not connect to ${DB_HOST}:${DB_PORT} (start cloud-sql-proxy and retry)."
  exit 0
fi

echo "Applied migrations in DB: ${count}"
if [[ "${count}" != "${expected}" ]]; then
  echo "WARN: migration count mismatch (expected ${expected}, got ${count})"
  exit 1
fi

for ver in 017_registry_catalog_suggestion_id 018_events_catalog_suggestion_id 019_photo_baby_tags 020_app_versions 021_worker_idempotency 022_user_profile_demographics 023_registry_shipping_structured; do
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
    "SELECT 1 FROM schema_migrations WHERE version = '${ver}'" | grep -q 1 || {
    echo "Missing migration row: ${ver}"
    exit 1
  }
done

psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  "SELECT column_name FROM information_schema.columns WHERE table_name = 'registry_items' AND column_name = 'catalog_suggestion_id'" \
  | grep -q catalog_suggestion_id

psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  "SELECT column_name FROM information_schema.columns WHERE table_name = 'events' AND column_name = 'catalog_suggestion_id'" \
  | grep -q catalog_suggestion_id

psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  "SELECT 1 FROM information_schema.tables WHERE table_name = 'photo_baby_tags'" | grep -q 1

echo "Dev migration gate OK (${count}/${expected})."
