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

FLOWS=(
  maestro/flows/smoke/auth_sign_in.yaml
  maestro/flows/smoke/shell_navigation.yaml
  maestro/flows/smoke/open_search.yaml
  maestro/flows/smoke/open_notifications.yaml
  maestro/flows/features/home_sections.yaml
  maestro/flows/features/baby_switcher.yaml
  maestro/flows/features/calendar_create.yaml
  maestro/flows/features/calendar_upcoming.yaml
  maestro/flows/features/registry_crud.yaml
  maestro/flows/features/fun_hub.yaml
  maestro/flows/features/gallery_browse.yaml
  maestro/flows/features/gallery_social.yaml
  maestro/flows/features/gallery_upload.yaml
  maestro/flows/features/followers_invite.yaml
  maestro/flows/features/account_settings.yaml
  maestro/flows/features/announce_arrival.yaml
  maestro/flows/features/registry_mark_purchased.yaml
  maestro/flows/features/registry_ai_suggestion_add.yaml
)

"${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" "${FLOWS[@]}"

# Follower role (separate sign-in credentials)
MAESTRO_ENV_ARGS=(
  "${MAESTRO_ENV_ARGS[@]}"
  -e "SIGN_IN_EMAIL=${FOLLOWER_TEST_EMAIL}"
  -e "SIGN_IN_PASSWORD=${FOLLOWER_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
)
"${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
  maestro/flows/roles/follower_permissions.yaml

# Invite deep link (requires token from provisioning)
if [[ -f "${ROOT}/maestro/.fixtures.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT}/maestro/.fixtures.env"
  set +a
fi
if [[ -n "${invite_token:-}" ]]; then
  export INVITE_TOKEN="${invite_token}"
  chmod +x "${ROOT}/maestro/scripts/open-invite-deep-link.sh"
  adb shell am force-stop com.lanonna.lanonna || true
  "${ROOT}/maestro/scripts/open-invite-deep-link.sh"
  sleep 5
  "${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
    maestro/flows/roles/invite_deep_link.yaml
else
  echo "Skipping invite_deep_link (no invite_token in .fixtures.env)" >&2
fi

# Fresh onboarding (dedicated user; re-provision smoke owner after)
REPO_ROOT="$(cd "${ROOT}/../.." && pwd)"
PYTHON="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
fi
export ONBOARDING_TEST_EMAIL="${ONBOARDING_TEST_EMAIL:-lanonna.dev.onboard@test.com}"
export ONBOARDING_TEST_PASSWORD="${ONBOARDING_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
cd "${REPO_ROOT}/infra/db"
"${PYTHON}" provision_maestro_fixtures.py onboarding_reset
cd "${ROOT}"
MAESTRO_ENV_ARGS=(
  -e "SMOKE_TEST_EMAIL=${SMOKE_TEST_EMAIL}"
  -e "SMOKE_TEST_PASSWORD=${SMOKE_TEST_PASSWORD}"
  -e "FOLLOWER_TEST_EMAIL=${FOLLOWER_TEST_EMAIL}"
  -e "FOLLOWER_TEST_PASSWORD=${FOLLOWER_TEST_PASSWORD:-}"
  -e "SIGN_IN_EMAIL=${ONBOARDING_TEST_EMAIL}"
  -e "SIGN_IN_PASSWORD=${ONBOARDING_TEST_PASSWORD}"
)
"${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
  maestro/flows/onboarding/onboarding_owner_fresh.yaml

"${ROOT}/maestro/scripts/provision-smoke-user.sh"
