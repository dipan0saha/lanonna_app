#!/usr/bin/env bash
# Maestro P0 regression suite (part 1; see maestro/flows/p0/COVERAGE.md).
# Run from repo root via `./scripts/premerge_check.sh --e2e`, or directly from apps/mobile.
#
# Needs: Maestro CLI, adb device ${ANDROID_SERIAL:-emulator-5554}, maestro/local.env
# (SMOKE_TEST_PASSWORD at least), Cloud SQL Auth Proxy on 127.0.0.1:${DB_PORT:-5433}
# for fixtures, gcloud/Firebase credentials for lanonna-dev.
#
# Optional flows (see local.env.example):
#   P0_DISPOSABLE_EMAIL_TEMPLATE  e.g. you+p0-{ts}@your-test-inbox.example; {ts} becomes a
#                                 timestamp. Runs sign-up with a new account, marks it
#                                 verified, then deletes it through the app (self-cleaning).
#   P0_RUN_BIOMETRIC=1            Biometric enable + biometric sign-in (needs an enrolled
#                                 fingerprint on the emulator).
#   P0_SKIP_BUILD=1               Reuse the installed debug APK instead of rebuilding.
#   MAESTRO_DEVICE_PIN            Emulator screen-lock PIN, used to unlock a cold-booted
#                                 emulator before the run.
#
# Exit status: 0 only when every flow that ran passed. Prints "P0 summary: ..." last.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/../.." && pwd)"
cd "${ROOT}"

export PATH="${HOME}/.maestro/bin:${PATH}"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
export MAESTRO_PREPARE_CLEAR=1
export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
APP_ID="com.lanonna.lanonna"
P0="maestro/flows/p0"

# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"

die() { echo "run-maestro-p0: $*" >&2; exit 1; }

[[ -n "${SMOKE_TEST_PASSWORD:-}" ]] || die "set SMOKE_TEST_PASSWORD in maestro/local.env"
command -v maestro >/dev/null 2>&1 || die "Maestro CLI not found (https://maestro.mobile.dev)"
adb -s "${ANDROID_SERIAL}" get-state 2>/dev/null | grep -q '^device$' \
  || die "no adb device ${ANDROID_SERIAL}; start the emulator first"
# A cold-booted emulator with a screen-lock PIN (needed for fingerprint enrollment) stays
# RUNNING_LOCKED: the app installs but its activities do not resolve and Maestro hangs.
if adb shell dumpsys user 2>/dev/null | grep -q 'RUNNING_LOCKED'; then
  [[ -n "${MAESTRO_DEVICE_PIN:-}" ]] \
    || die "emulator user is locked; unlock it on screen or set MAESTRO_DEVICE_PIN in maestro/local.env"
  adb shell input keyevent KEYCODE_WAKEUP
  adb shell wm dismiss-keyguard
  sleep 1
  adb shell input text "${MAESTRO_DEVICE_PIN}"
  adb shell input keyevent KEYCODE_ENTER
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    adb shell dumpsys user 2>/dev/null | grep -q 'RUNNING_LOCKED' || break
    sleep 1
  done
  if adb shell dumpsys user 2>/dev/null | grep -q 'RUNNING_LOCKED'; then
    die "emulator user still locked after entering MAESTRO_DEVICE_PIN"
  fi
fi
DB_PORT="${DB_PORT:-5433}"
nc -z 127.0.0.1 "${DB_PORT}" >/dev/null 2>&1 \
  || die "nothing on 127.0.0.1:${DB_PORT}; start the Cloud SQL Auth Proxy for lanonna-dev"

# Fixture scripts need psycopg + firebase-admin.
if [[ -z "${PYTHON:-}" ]]; then
  for c in "${REPO_ROOT}/infra/db/.venv/bin/python" "${REPO_ROOT}/services/api/.venv/bin/python" python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import psycopg, firebase_admin' 2>/dev/null; then
      PYTHON="$c"; break
    fi
  done
fi
[[ -n "${PYTHON:-}" ]] || die "no Python with psycopg + firebase-admin; pip install -r infra/db/requirements.txt into infra/db/.venv or set PYTHON"
export PYTHON

# Fixture commands below (onboarding_reset, mark verified) connect to Cloud SQL directly;
# provision-smoke-user.sh runs in a child shell, so fetch the dev DB password here too.
if [[ -z "${DB_PASSWORD:-}" && -z "${PGPASSWORD:-}" ]] && command -v gcloud >/dev/null 2>&1; then
  DB_PASSWORD="$(gcloud secrets versions access latest \
    --secret=db-lanonna-app-password --project=lanonna-dev 2>/dev/null || true)"
  if [[ -n "${DB_PASSWORD}" ]]; then export DB_PASSWORD PGPASSWORD="${DB_PASSWORD}"; fi
fi
export DB_HOST="${DB_HOST:-127.0.0.1}" DB_PORT

export ONBOARDING_TEST_EMAIL="${ONBOARDING_TEST_EMAIL:-lanonna.dev.onboard@test.com}"
export ONBOARDING_TEST_PASSWORD="${ONBOARDING_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"

chmod +x "${ROOT}/maestro/scripts/"*.sh
"${ROOT}/maestro/scripts/provision-smoke-user.sh"
if [[ "${P0_SKIP_BUILD:-0}" != "1" ]]; then
  "${ROOT}/maestro/scripts/build-install.sh"
fi
"${ROOT}/maestro/scripts/prepare-emulator-for-maestro.sh"

# Sourced (not executed) so the array stays in this shell: bash cannot export arrays
# to child processes, which is why flows get their -e flags from run_flow below.
# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/maestro-env-args.sh"
[[ -n "${SECOND_BABY_SWITCHER_ID:-}${second_baby_profile_id:-}" ]] || die "fixtures did not write second_baby_profile_id"
BASE_ENV=(
  "${MAESTRO_ENV_ARGS[@]}"
  -e "ONBOARDING_TEST_EMAIL=${ONBOARDING_TEST_EMAIL}"
  -e "ONBOARDING_TEST_PASSWORD=${ONBOARDING_TEST_PASSWORD}"
)

PASSED=()
FAILED=()
SKIPPED=()

# run_flow <flow.yaml> [extra maestro -e flags...]
run_flow() {
  local flow="$1"; shift
  echo ""
  echo "======== Maestro: ${flow} ========"
  if maestro test "${flow}" "${BASE_ENV[@]}" "$@"; then
    PASSED+=("$(basename "${flow}" .yaml)")
  else
    FAILED+=("$(basename "${flow}" .yaml)")
    return 1
  fi
}

skip_flow() { SKIPPED+=("$1"); echo "SKIP $1: $2" >&2; }

# Core flows: owner smoke account.
for f in auth_sign_in auth_sign_out gallery_upload invite_send; do
  run_flow "${P0}/${f}.yaml" || true
done

# Owner onboarding: reset the dedicated account to "not onboarded" first.
if (cd "${REPO_ROOT}/infra/db" && "${PYTHON}" provision_maestro_fixtures.py onboarding_reset >/dev/null); then
  run_flow "${P0}/owner_onboarding.yaml" || true
else
  FAILED+=("owner_onboarding (fixture reset)")
fi

# Invite deep link: provisioning wrote a fresh follower invite for the second baby.
if [[ -n "${invite_token:-}" ]]; then
  # The flow opens the link itself (openLink) after Maestro launches the app.
  run_flow "${P0}/invite_accept_deep_link.yaml" -e "INVITE_TOKEN=${invite_token}" || true
else
  FAILED+=("invite_accept_deep_link (no invite_token in maestro/.fixtures.env)")
fi

# Biometric flows (emulator must have an enrolled fingerprint).
if [[ "${P0_RUN_BIOMETRIC:-0}" == "1" ]]; then
  run_flow "${P0}/settings_biometric_enable.yaml" \
    && run_flow "${P0}/auth_biometric_sign_in.yaml" || true
else
  skip_flow settings_biometric_enable "set P0_RUN_BIOMETRIC=1"
  skip_flow auth_biometric_sign_in "set P0_RUN_BIOMETRIC=1"
fi

# Sign-up + account delete on a brand-new disposable account (cleans up after itself).
if [[ -n "${P0_DISPOSABLE_EMAIL_TEMPLATE:-}" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  disposable_email="${P0_DISPOSABLE_EMAIL_TEMPLATE//\{ts\}/${ts}}"
  [[ "${disposable_email}" != "${P0_DISPOSABLE_EMAIL_TEMPLATE}" ]] \
    || die "P0_DISPOSABLE_EMAIL_TEMPLATE must contain {ts}"
  disposable_password="P0a1!$(openssl rand -hex 12)"
  disposable_env=(
    -e "P0_DISPOSABLE_EMAIL=${disposable_email}"
    -e "P0_DISPOSABLE_PASSWORD=${disposable_password}"
  )
  if run_flow "${P0}/auth_sign_up.yaml" "${disposable_env[@]}"; then
    if (cd "${REPO_ROOT}" && \
        "${PYTHON}" scripts/mark_firebase_email_verified.py "${disposable_email}" >/dev/null); then
      if ! run_flow "${P0}/account_delete.yaml" "${disposable_env[@]}"; then
        echo "account_delete failed; remove the disposable account with:" >&2
        echo "  scripts/delete_dev_account.sh '<the P0_DISPOSABLE_EMAIL_TEMPLATE address for ${ts}>'" >&2
      fi
    else
      FAILED+=("account_delete (could not mark the disposable account verified)")
    fi
  else
    skip_flow account_delete "sign-up failed, nothing to delete"
  fi
  unset disposable_password disposable_env
else
  skip_flow auth_sign_up "set P0_DISPOSABLE_EMAIL_TEMPLATE"
  skip_flow account_delete "set P0_DISPOSABLE_EMAIL_TEMPLATE"
fi

# Put the shared fixtures back (onboarding/invite flows changed them).
"${ROOT}/maestro/scripts/provision-smoke-user.sh" >/dev/null

echo ""
echo "Passed: ${PASSED[*]:-none}"
echo "Failed: ${FAILED[*]:-none}"
echo "Skipped: ${SKIPPED[*]:-none}"
echo "P0 summary: ${#PASSED[@]} passed, ${#FAILED[@]} failed, ${#SKIPPED[@]} skipped"
[[ ${#FAILED[@]} -eq 0 ]]
