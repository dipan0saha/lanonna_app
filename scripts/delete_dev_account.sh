#!/usr/bin/env bash
# Delete a dev account by email through the product delete path (SQL + GCS + Firebase).
# Cloud SQL proxy on DB_PORT (default 5433).
set -euo pipefail

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 <email> [--dry-run]" >&2
  exit 1
fi

EMAIL="$1"
shift

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_DIR="${ROOT}/infra/db"
VENV="${DB_DIR}/.venv"

export ENVIRONMENT="${ENVIRONMENT:-dev}"
export GCP_PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5433}"

if [[ -z "${DB_PASSWORD:-}" && -z "${PGPASSWORD:-}" ]]; then
  if command -v gcloud >/dev/null 2>&1; then
    DB_PASSWORD="$(gcloud secrets versions access latest \
      --secret=db-lanonna-app-password \
      --project="${GCP_PROJECT_ID}")"
    export DB_PASSWORD
  else
    echo "Set DB_PASSWORD or PGPASSWORD, or install gcloud to load the dev secret." >&2
    exit 1
  fi
else
  export DB_PASSWORD="${DB_PASSWORD:-${PGPASSWORD}}"
fi

if [[ ! -x "${VENV}/bin/python" ]]; then
  python3 -m venv "${VENV}"
fi
"${VENV}/bin/pip" install -q -r "${DB_DIR}/requirements.txt" \
  -r "${ROOT}/services/api/requirements.txt"

export PYTHONPATH="${ROOT}/services/api/src:${ROOT}/packages/lanonna_activity_copy/src"
cd "${DB_DIR}"
exec "${VENV}/bin/python" delete_dev_account.py --email "${EMAIL}" "$@"
