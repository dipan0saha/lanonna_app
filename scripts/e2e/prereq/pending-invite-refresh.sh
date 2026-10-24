#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MOBILE="${REPO_ROOT}/apps/mobile"
# shellcheck disable=SC1091
source "${MOBILE}/maestro/scripts/load-env.sh"
export MAESTRO_FIXTURES_OUT="${MOBILE}/maestro/.fixtures.env"
"${MOBILE}/maestro/scripts/provision-smoke-user.sh" >/dev/null 2>&1 || true
PYTHON="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
fi
cd "${REPO_ROOT}/infra/db"
"${PYTHON}" provision_maestro_fixtures.py pending_invite_refresh
