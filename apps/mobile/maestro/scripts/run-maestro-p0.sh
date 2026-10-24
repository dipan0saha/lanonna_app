#!/usr/bin/env bash
# Maestro P0 regression suite (part 1). Run from apps/mobile via premerge_check.sh --e2e
# or directly after build-install + local.env credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.maestro/bin"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
export MAESTRO_PREPARE_CLEAR=1
export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"

# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"
# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/maestro-env-args.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env" >&2
  exit 1
fi

if ! command -v maestro >/dev/null 2>&1; then
  echo "Maestro CLI not found (https://maestro.mobile.dev)" >&2
  exit 1
fi

if ! adb devices | grep -q "${ANDROID_SERIAL}.*device"; then
  echo "No adb device ${ANDROID_SERIAL}; start the Android emulator first." >&2
  exit 1
fi

chmod +x "${ROOT}/maestro/scripts/"*.sh

"${ROOT}/maestro/scripts/provision-smoke-user.sh"
"${ROOT}/maestro/scripts/build-install.sh"
"${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"

CORE_FLOWS=(
  maestro/flows/p0/auth_sign_in.yaml
  maestro/flows/p0/auth_sign_out.yaml
  maestro/flows/p0/gallery_upload.yaml
  maestro/flows/p0/invite_send.yaml
)

"${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" "${CORE_FLOWS[@]}"

# Optional flows (extra credentials / destructive)
if [[ -n "${P0_SIGNUP_TEST_EMAIL:-}" && -n "${P0_SIGNUP_TEST_PASSWORD:-}" ]]; then
  MAESTRO_ENV_ARGS+=(
    -e "P0_SIGNUP_TEST_EMAIL=${P0_SIGNUP_TEST_EMAIL}"
    -e "P0_SIGNUP_TEST_PASSWORD=${P0_SIGNUP_TEST_PASSWORD}"
  )
  "${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
    maestro/flows/p0/auth_sign_up.yaml
else
  echo "SKIP auth_sign_up (set P0_SIGNUP_TEST_EMAIL and P0_SIGNUP_TEST_PASSWORD in local.env)" >&2
fi

export ONBOARDING_TEST_EMAIL="${ONBOARDING_TEST_EMAIL:-lanonna.dev.onboard@test.com}"
export ONBOARDING_TEST_PASSWORD="${ONBOARDING_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
MAESTRO_ENV_ARGS=(
  "${MAESTRO_ENV_ARGS[@]}"
  -e "SIGN_IN_EMAIL=${ONBOARDING_TEST_EMAIL}"
  -e "SIGN_IN_PASSWORD=${ONBOARDING_TEST_PASSWORD}"
)
REPO_ROOT="$(cd "${ROOT}/../.." && pwd)"
PYTHON="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
fi
cd "${REPO_ROOT}/infra/db"
"${PYTHON}" provision_maestro_fixtures.py onboarding_reset
cd "${ROOT}"
"${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
  maestro/flows/p0/owner_onboarding.yaml

# Invite deep link (follower credentials)
if [[ -f "${ROOT}/maestro/.fixtures.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT}/maestro/.fixtures.env"
  set +a
fi
if [[ -n "${invite_token:-}" ]]; then
  export INVITE_TOKEN="${invite_token}"
  adb shell am force-stop com.lanonna.lanonna || true
  "${ROOT}/maestro/scripts/open-invite-deep-link.sh"
  sleep 5
  MAESTRO_ENV_ARGS=(
    "${MAESTRO_ENV_ARGS[@]}"
    -e "SIGN_IN_EMAIL=${FOLLOWER_TEST_EMAIL}"
    -e "SIGN_IN_PASSWORD=${FOLLOWER_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
  )
  "${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
    maestro/flows/p0/invite_accept_deep_link.yaml
else
  echo "SKIP invite_accept_deep_link (no invite_token in maestro/.fixtures.env)" >&2
fi

# Biometric flows (emulator-dependent)
if [[ "${P0_RUN_BIOMETRIC:-0}" == "1" ]]; then
  MAESTRO_ENV_ARGS=(
    -e "SMOKE_TEST_EMAIL=${SMOKE_TEST_EMAIL}"
    -e "SMOKE_TEST_PASSWORD=${SMOKE_TEST_PASSWORD}"
  )
  "${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
    maestro/flows/p0/settings_biometric_enable.yaml \
    maestro/flows/p0/auth_biometric_sign_in.yaml
else
  echo "SKIP biometric P0 (set P0_RUN_BIOMETRIC=1 in local.env to enable)" >&2
fi

if [[ -n "${P0_ACCOUNT_DELETE_TEST_EMAIL:-}" && -n "${P0_ACCOUNT_DELETE_TEST_PASSWORD:-}" ]]; then
  MAESTRO_ENV_ARGS=(
    -e "P0_ACCOUNT_DELETE_TEST_EMAIL=${P0_ACCOUNT_DELETE_TEST_EMAIL}"
    -e "P0_ACCOUNT_DELETE_TEST_PASSWORD=${P0_ACCOUNT_DELETE_TEST_PASSWORD}"
  )
  "${ROOT}/maestro/scripts/run-maestro-flows-sequential.sh" \
    maestro/flows/p0/account_delete.yaml
else
  echo "SKIP account_delete (set P0_ACCOUNT_DELETE_TEST_* in local.env)" >&2
fi

"${ROOT}/maestro/scripts/provision-smoke-user.sh"
echo "Maestro P0 suite finished."
