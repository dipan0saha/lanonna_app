#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MOBILE="${REPO_ROOT}/apps/mobile"
"${REPO_ROOT}/scripts/e2e/prereq/pending-invite-refresh.sh"
if [[ -f "${MOBILE}/maestro/.fixtures.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${MOBILE}/maestro/.fixtures.env"
  set +a
fi
if [[ -z "${invite_token:-}" ]]; then
  echo "invite_token missing after pending_invite_refresh" >&2
  exit 1
fi
export INVITE_TOKEN="${invite_token}"
adb shell am force-stop com.lanonna.lanonna || true
"${MOBILE}/maestro/scripts/open-invite-deep-link.sh"
sleep 3
