#!/usr/bin/env bash
# Provisions Maestro SQL + Firebase fixtures (owner, follower, seeds).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env" >&2
  exit 1
fi

if [[ -z "${FOLLOWER_TEST_PASSWORD:-}" ]]; then
  export FOLLOWER_TEST_PASSWORD="${SMOKE_TEST_PASSWORD}"
fi

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

export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5433}"
export SMOKE_TEST_EMAIL SMOKE_TEST_PASSWORD FOLLOWER_TEST_EMAIL FOLLOWER_TEST_PASSWORD
export MAESTRO_FIXTURES_OUT="${ROOT}/maestro/.fixtures.env"

PYTHON="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
fi

echo "Provisioning Maestro fixtures (Cloud SQL + Firebase)…"
cd "${REPO_ROOT}/infra/db"
"${PYTHON}" provision_maestro_fixtures.py all
