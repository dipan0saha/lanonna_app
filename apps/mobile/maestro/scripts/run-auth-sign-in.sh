#!/usr/bin/env bash
# Cold-start auth Maestro flow: clear → register App Check → relaunch → test.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

export PATH="${PATH}:${HOME}/.maestro/bin"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env" >&2
  exit 1
fi

chmod +x "${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"
"${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"

maestro test maestro/flows/smoke/auth_sign_in.yaml \
  -e "SMOKE_TEST_EMAIL=${SMOKE_TEST_EMAIL}" \
  -e "SMOKE_TEST_PASSWORD=${SMOKE_TEST_PASSWORD}"
