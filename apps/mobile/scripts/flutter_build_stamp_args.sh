#!/usr/bin/env bash
# Prints flutter CLI args for build stamping (--build-number and dart-defines).
set -euo pipefail

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
eval "$(bash "${MOBILE}/scripts/build_stamp.sh")"

printf '%s\n' \
  "--build-number=${BUILD_NUMBER}" \
  "--dart-define=BUILD_GIT_SHA=${BUILD_GIT_SHA}" \
  "--dart-define=BUILD_NUMBER=${BUILD_NUMBER}"
