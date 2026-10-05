#!/usr/bin/env bash
# Hard-delete a dev user by email (SQL + GCS + Firebase). Cloud SQL proxy on DB_PORT (default 5433).
set -euo pipefail

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 <email> [--dry-run] [--skip-gcs] [--skip-firebase]" >&2
  echo "Example: $0 abc@test.com" >&2
  exit 1
fi

EMAIL="$1"
shift

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_DIR="${ROOT}/infra/db"
VENV="${DB_DIR}/.venv"

export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-5433}"

if [[ -z "${DB_PASSWORD:-}" && -z "${PGPASSWORD:-}" ]]; then
  if command -v gcloud >/dev/null 2>&1; then
    export PGPASSWORD
    PGPASSWORD="$(gcloud secrets versions access latest \
      --secret=db-lanonna-app-password \
      --project=lanonna-dev)"
    export DB_PASSWORD="${PGPASSWORD}"
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
"${VENV}/bin/pip" install -q -r "${DB_DIR}/requirements.txt"

cd "${DB_DIR}"
exec "${VENV}/bin/python" hard_delete_user.py --email "${EMAIL}" "$@"
