#!/usr/bin/env bash
# Run Maestro flows one at a time; exit on first failure (set -e).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -z "${MAESTRO_ENV_ARGS[*]:-}" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/maestro/scripts/load-env.sh"
  # shellcheck disable=SC1091
  source "${ROOT}/maestro/scripts/maestro-env-args.sh"
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: run-maestro-flows-sequential.sh <flow.yaml> ..." >&2
  exit 1
fi

export PATH="${PATH}:${HOME}/.maestro/bin}"

for flow in "$@"; do
  echo ""
  echo "======== Maestro: ${flow} ========"
  maestro test "${flow}" "${MAESTRO_ENV_ARGS[@]}"
done
