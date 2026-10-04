#!/usr/bin/env bash
# Provision QA owner + follower on lanonna-dev (Firebase + Cloud SQL) and seed gallery photo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="${REPO_ROOT}/apps/mobile"
# shellcheck disable=SC1091
source "${MOBILE}/maestro/scripts/load-env.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in apps/mobile/maestro/local.env" >&2
  exit 1
fi

export QA_TEST_PASSWORD="${QA_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
export QA_OWNER_EMAIL="${QA_OWNER_EMAIL:-lanonna.dev.qa.owner@test.com}"
export QA_FOLLOWER_EMAIL="${QA_FOLLOWER_EMAIL:-lanonna.dev.qa.follower@test.com}"
export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5433}"

if [[ -z "${DB_PASSWORD:-}" && -z "${PGPASSWORD:-}" ]]; then
  if command -v gcloud >/dev/null 2>&1; then
    export PGPASSWORD
    PGPASSWORD="$(gcloud secrets versions access latest \
      --secret=db-lanonna-app-password \
      --project=lanonna-dev 2>/dev/null || true)"
    if [[ -n "${PGPASSWORD}" ]]; then
      export DB_PASSWORD="${PGPASSWORD}"
    fi
  fi
fi

FIXTURES_OUT="${MOBILE}/maestro/.qa-fixtures.env"
export MAESTRO_FIXTURES_OUT="${FIXTURES_OUT}"

PYTHON="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
fi

echo "Provisioning QA validation accounts (Cloud SQL proxy on ${DB_HOST}:${DB_PORT})…"
cd "${REPO_ROOT}/infra/db"
"${PYTHON}" provision_maestro_fixtures.py qa

echo ""
echo "Uploading real gallery photo via API (owner)…"
"${REPO_ROOT}/scripts/seed_qa_gallery_photo.sh"

echo ""
echo "Done. Sign in on the emulator with:"
echo "  Owner:    ${QA_OWNER_EMAIL}"
echo "  Follower: ${QA_FOLLOWER_EMAIL}"
echo "  Password: (same as SMOKE_TEST_PASSWORD in maestro/local.env)"
echo "Fixture ids: ${FIXTURES_OUT}"
