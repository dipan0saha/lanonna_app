#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.maestro/bin"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
export MAESTRO_AUTO_LOGIN=1

# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env (see local.env.example)" >&2
  exit 1
fi

"${ROOT}/maestro/scripts/build-install.sh"

chmod +x "${ROOT}/maestro/scripts/provision-smoke-user.sh"
"${ROOT}/maestro/scripts/provision-smoke-user.sh"

chmod +x "${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"
export MAESTRO_PREPARE_CLEAR=0
"${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"

maestro test \
  maestro/flows/smoke/shell_navigation.yaml \
  maestro/flows/smoke/open_search.yaml \
  maestro/flows/smoke/open_notifications.yaml \
  -e "SMOKE_TEST_EMAIL=${SMOKE_TEST_EMAIL}" \
  -e "SMOKE_TEST_PASSWORD=${SMOKE_TEST_PASSWORD}"
