#!/usr/bin/env bash
# P0 Maestro E2E runner (Android emulator). Exits non-zero on any flow failure.
#
# Usage:
#   ./scripts/e2e/run_smoke.sh [--smoke|--full] [--tag NAME] [--skip-provision] [--skip-build]
#   ./scripts/e2e/run_smoke.sh --flow maestro/flows/smoke/auth_sign_in.yaml
#
# Env: SMOKE_TEST_PASSWORD (required), optional LANONNA_QA_ENV_FILE,
#      ANDROID_SERIAL (default emulator-5554), E2E_OUTPUT_DIR (default repo/.e2e-out).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MOBILE="${REPO_ROOT}/apps/mobile"
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/e2e/flows-manifest.sh"

MODE="smoke"
SKIP_PROVISION=0
SKIP_BUILD=0
EXTRA_FLOWS=()

usage() {
  sed -n '2,8p' "$0"
  echo "  --tag NAME    Run a named tag from flows-manifest.sh (invite, auth, registry, destructive)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke) MODE="smoke" ;;
    --full) MODE="full" ;;
    --tag)
      MODE="tag"
      TAG_NAME="${2:?--tag requires a name}"
      shift
      ;;
    --skip-provision) SKIP_PROVISION=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --flow)
      EXTRA_FLOWS+=("${2:?--flow requires path}")
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
export PATH="${PATH}:${HOME}/.maestro/bin"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

# shellcheck disable=SC1091
source "${MOBILE}/maestro/scripts/load-env.sh"
# shellcheck disable=SC1091
source "${MOBILE}/maestro/scripts/maestro-env-args.sh"

if [[ -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env or ~/Neo_Workspace/qa_secrets/lanonna_qa363_accounts.env" >&2
  exit 1
fi

if ! adb -s "${ANDROID_SERIAL}" get-state >/dev/null 2>&1; then
  echo "No Android device at ANDROID_SERIAL=${ANDROID_SERIAL}" >&2
  exit 1
fi

FLOWS=()
if ((${#EXTRA_FLOWS[@]} > 0)); then
  FLOWS=("${EXTRA_FLOWS[@]}")
else
  case "${MODE}" in
    smoke) FLOWS=("${E2E_SMOKE_FLOWS[@]}") ;;
    full) FLOWS=("${E2E_FULL_FLOWS[@]}") ;;
    tag)
      if [[ -z "${E2E_TAG_FLOWS[$TAG_NAME]:-}" ]]; then
        echo "Unknown tag: ${TAG_NAME}" >&2
        exit 1
      fi
      # shellcheck disable=SC2206
      FLOWS=(${E2E_TAG_FLOWS[$TAG_NAME]})
      ;;
  esac
fi

E2E_OUTPUT_DIR="${E2E_OUTPUT_DIR:-${REPO_ROOT}/.e2e-out}"
RUN_DIR="${E2E_OUTPUT_DIR}/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${RUN_DIR}/screenshots" "${RUN_DIR}/junit"

chmod +x "${MOBILE}/maestro/scripts/"*.sh "${REPO_ROOT}/scripts/e2e/prereq/"*.sh

if [[ "${SKIP_PROVISION}" -eq 0 ]]; then
  echo "Provisioning smoke fixtures…"
  "${MOBILE}/maestro/scripts/provision-smoke-user.sh"
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  cd "${MOBILE}"
  # TODO: when scripts/build_stamp.sh lands (PR #438), source it here and pass
  # stamped version defines into build-install.sh for reproducible APK labels.
  "${MOBILE}/maestro/scripts/build-install.sh"
  export MAESTRO_PREPARE_CLEAR=1
  "${MOBILE}/maestro/scripts/prepare-emulator-for-maestro.sh"
fi

cd "${MOBILE}"

FAILED=0
FLOW_INDEX=0
for flow in "${FLOWS[@]}"; do
  FLOW_INDEX=$((FLOW_INDEX + 1))
  rel="${flow#maestro/}"
  slug="${rel//\//_}"
  slug="${slug%.yaml}"

  case "${flow}" in
    maestro/flows/roles/invite_accept_signed_out.yaml|maestro/flows/roles/invite_login_resume_427.yaml|maestro/flows/roles/invite_decline.yaml|maestro/flows/roles/invite_deep_link.yaml)
      "${REPO_ROOT}/scripts/e2e/prereq/open-follower-invite-link.sh"
      if [[ -f maestro/.fixtures.env ]]; then
        set -a
        # shellcheck disable=SC1091
        source maestro/.fixtures.env
        set +a
        MAESTRO_ENV_ARGS+=(-e "INVITE_TOKEN=${invite_token}")
      fi
      ;;
    maestro/flows/roles/invite_wrong_account_switch.yaml)
      "${REPO_ROOT}/scripts/e2e/prereq/pending-invite-refresh.sh"
      if [[ -f maestro/.fixtures.env ]]; then
        set -a
        # shellcheck disable=SC1091
        source maestro/.fixtures.env
        set +a
        export INVITE_TOKEN="${invite_token}"
        MAESTRO_ENV_ARGS+=(-e "INVITE_TOKEN=${invite_token}")
      fi
      ;;
    maestro/flows/destructive/account_delete_throwaway.yaml|maestro/flows/destructive/baby_hard_delete_throwaway.yaml)
      "${REPO_ROOT}/scripts/e2e/prereq/throwaway-sole-owner.sh"
      if [[ -f maestro/.fixtures.env ]]; then
        set -a
        # shellcheck disable=SC1091
        source maestro/.fixtures.env
        set +a
        MAESTRO_ENV_ARGS+=(
          -e "SIGN_IN_EMAIL=${throwaway_email}"
          -e "SIGN_IN_PASSWORD=${throwaway_password}"
          -e "THROWAWAY_BABY_ID=${throwaway_baby_profile_id}"
        )
      fi
      ;;
    maestro/flows/features/auth_unverified_gate.yaml)
      "${REPO_ROOT}/scripts/e2e/prereq/unverified-user.sh"
      if [[ -f maestro/.fixtures.env ]]; then
        set -a
        # shellcheck disable=SC1091
        source maestro/.fixtures.env
        set +a
        MAESTRO_ENV_ARGS+=(
          -e "SIGN_IN_EMAIL=${unverified_test_email}"
          -e "SIGN_IN_PASSWORD=${unverified_test_password}"
        )
      fi
      ;;
    maestro/flows/roles/follower_permissions.yaml|maestro/flows/roles/registry_claim_follower.yaml)
      MAESTRO_ENV_ARGS=(
        "${MAESTRO_ENV_ARGS[@]}"
        -e "SIGN_IN_EMAIL=${FOLLOWER_TEST_EMAIL}"
        -e "SIGN_IN_PASSWORD=${FOLLOWER_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
      )
      ;;
    maestro/flows/onboarding/onboarding_owner_fresh.yaml|maestro/flows/onboarding/onboarding_owner_resilience.yaml)
      export ONBOARDING_TEST_EMAIL="${ONBOARDING_TEST_EMAIL:-lanonna.dev.onboard@test.com}"
      export ONBOARDING_TEST_PASSWORD="${ONBOARDING_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}"
      PYTHON="${PYTHON:-python3}"
      if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
        PYTHON="${REPO_ROOT}/services/api/.venv/bin/python"
      fi
      (cd "${REPO_ROOT}/infra/db" && "${PYTHON}" provision_maestro_fixtures.py onboarding_reset)
      MAESTRO_ENV_ARGS+=(
        -e "SIGN_IN_EMAIL=${ONBOARDING_TEST_EMAIL}"
        -e "SIGN_IN_PASSWORD=${ONBOARDING_TEST_PASSWORD}"
      )
      ;;
  esac

  echo ""
  echo "======== [${FLOW_INDEX}/${#FLOWS[@]}] Maestro: ${flow} ========"
  junit_file="${RUN_DIR}/junit/${slug}.xml"
  if ! maestro test "${flow}" "${MAESTRO_ENV_ARGS[@]}" \
    --format junit \
    --output "${junit_file}" \
    --test-output-dir "${RUN_DIR}/screenshots/${slug}"; then
    FAILED=1
    echo "FAILED: ${flow}" >&2
    break
  fi
done

if [[ "${FAILED}" -eq 0 ]]; then
  echo ""
  echo "All ${#FLOWS[@]} flow(s) passed."
  echo "JUnit reports: ${RUN_DIR}/junit/"
  echo "Screenshots:    ${RUN_DIR}/screenshots/"
  exit 0
fi

echo "Maestro run failed. Artifacts: ${RUN_DIR}" >&2
exit 1
