#!/usr/bin/env bash
# Sources maestro/local.env when present; exports SMOKE_TEST_* for Maestro -e flags.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${ROOT}/maestro/local.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ -z "${SMOKE_TEST_EMAIL:-}" ]]; then
  SMOKE_TEST_EMAIL="lanonna.dev.smoke@test.com"
fi
if [[ -z "${FOLLOWER_TEST_EMAIL:-}" ]]; then
  FOLLOWER_TEST_EMAIL="lanonna.dev.follower@test.com"
fi

export SMOKE_TEST_EMAIL
export SMOKE_TEST_PASSWORD
export FOLLOWER_TEST_EMAIL
if [[ -z "${FOLLOWER_TEST_PASSWORD:-}" && -n "${SMOKE_TEST_PASSWORD:-}" ]]; then
  FOLLOWER_TEST_PASSWORD="${SMOKE_TEST_PASSWORD}"
fi
export FOLLOWER_TEST_PASSWORD
