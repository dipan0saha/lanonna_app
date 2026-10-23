#!/usr/bin/env bash
# Regression: default Firebase API key lookup for dev infra scripts (#425).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="$("${ROOT}/scripts/read_firebase_api_key.sh")"
if [[ -z "${KEY}" ]]; then
  echo "read_firebase_api_key.sh returned an empty key" >&2
  exit 1
fi
if [[ ! "${KEY}" =~ ^AIza ]]; then
  echo "Unexpected Firebase API key format" >&2
  exit 1
fi
echo "read_firebase_api_key.sh OK"
