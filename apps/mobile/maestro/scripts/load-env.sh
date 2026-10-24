#!/usr/bin/env bash
# Sources maestro/local.env when present; exports SMOKE_TEST_* for Maestro -e flags.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Credentials never committed — load first match (public repo).
QA_ENV_CANDIDATES=()
if [[ -n "${LANONNA_QA_ENV_FILE:-}" ]]; then
  QA_ENV_CANDIDATES+=("${LANONNA_QA_ENV_FILE}")
fi
QA_ENV_CANDIDATES+=(
  "${HOME}/Neo_Workspace/qa_secrets/lanonna_qa363_accounts.env"
  "${ROOT}/maestro/local.env"
)
for candidate in "${QA_ENV_CANDIDATES[@]}"; do
  if [[ -f "${candidate}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${candidate}"
    set +a
    break
  fi
done

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
