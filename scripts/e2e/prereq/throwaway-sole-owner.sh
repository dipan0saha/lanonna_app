#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MOBILE="${REPO_ROOT}/apps/mobile"
# shellcheck disable=SC1091
source "${MOBILE}/maestro/scripts/load-env.sh"
export E2E_RUN_ID="${E2E_RUN_ID:-$(date +%s)}"
export MAESTRO_FIXTURES_OUT="${MOBILE}/maestro/.fixtures.env"
PYTHON="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
fi
cd "${REPO_ROOT}/infra/db"
"${PYTHON}" provision_maestro_fixtures.py throwaway_sole_owner
