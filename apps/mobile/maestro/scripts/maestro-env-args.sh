#!/usr/bin/env bash
# Prints Maestro -e flags from load-env + optional fixtures file.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/maestro/scripts/load-env.sh"
if [[ -f "${ROOT}/maestro/.fixtures.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT}/maestro/.fixtures.env"
  set +a
fi
MAESTRO_ENV_ARGS=(
  -e "SMOKE_TEST_EMAIL=${SMOKE_TEST_EMAIL}"
  -e "SMOKE_TEST_PASSWORD=${SMOKE_TEST_PASSWORD}"
  -e "FOLLOWER_TEST_EMAIL=${FOLLOWER_TEST_EMAIL}"
  -e "FOLLOWER_TEST_PASSWORD=${FOLLOWER_TEST_PASSWORD:-}"
)
if [[ -n "${invite_token:-}" ]]; then
  MAESTRO_ENV_ARGS+=(-e "INVITE_TOKEN=${invite_token}")
fi
if [[ -n "${baby_profile_id:-}" ]]; then
  MAESTRO_ENV_ARGS+=(-e "PRIMARY_BABY_SWITCHER_ID=${baby_profile_id//-/_}")
fi
if [[ -n "${second_baby_profile_id:-}" ]]; then
  MAESTRO_ENV_ARGS+=(-e "SECOND_BABY_SWITCHER_ID=${second_baby_profile_id//-/_}")
fi
if [[ -n "${ONBOARDING_TEST_EMAIL:-}" ]]; then
  MAESTRO_ENV_ARGS+=(-e "ONBOARDING_TEST_EMAIL=${ONBOARDING_TEST_EMAIL}")
  MAESTRO_ENV_ARGS+=(-e "SIGN_IN_EMAIL=${ONBOARDING_TEST_EMAIL}")
  MAESTRO_ENV_ARGS+=(-e "SIGN_IN_PASSWORD=${ONBOARDING_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD}}")
fi

export MAESTRO_ENV_ARGS
