#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.maestro/bin"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
export MAESTRO_PREPARE_CLEAR=1

# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"
# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/maestro-env-args.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env" >&2
  exit 1
fi

chmod +x "${ROOT}/maestro/scripts/"*.sh

"${ROOT}/maestro/scripts/provision-smoke-user.sh"
"${ROOT}/maestro/scripts/build-install.sh"
"${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"

"${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
  maestro/flows/smoke/auth_sign_in.yaml \
  maestro/flows/smoke/shell_navigation.yaml \
  maestro/flows/smoke/open_search.yaml \
  maestro/flows/smoke/open_notifications.yaml
