#!/usr/bin/env bash
# Run Maestro flows one at a time; exit on first failure (set -e).
#
#   run-maestro-flows-sequential.sh <flow.yaml> ...
#   run-maestro-flows-sequential.sh -e KEY=VALUE ... -- <flow.yaml> ...
#
# Bash cannot export arrays, so a caller's MAESTRO_ENV_ARGS never reaches this
# process. Callers that changed it (follower sign-in, onboarding user) must pass
# the flags explicitly before `--`; otherwise the defaults from local.env apply.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ENV_ARGS=()
if [[ " $* " == *" -- "* ]]; then
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    ENV_ARGS+=("$1")
    shift
  done
  shift
else
  # shellcheck disable=SC1091
  source "${ROOT}/maestro/scripts/load-env.sh"
  # shellcheck disable=SC1091
  source "${ROOT}/maestro/scripts/maestro-env-args.sh"
  ENV_ARGS=("${MAESTRO_ENV_ARGS[@]}")
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: run-maestro-flows-sequential.sh [-e KEY=VALUE ... --] <flow.yaml> ..." >&2
  exit 1
fi

export PATH="${HOME}/.maestro/bin:${PATH}"

for flow in "$@"; do
  echo ""
  echo "======== Maestro: ${flow} ========"
  maestro test "${flow}" "${ENV_ARGS[@]}"
done
