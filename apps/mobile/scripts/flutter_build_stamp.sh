#!/usr/bin/env bash
# Shared build stamp for flutter_build_apk.sh and flutter_build_appbundle.sh.
# Source after MOBILE is set; sets BUILD_GIT_SHA, BUILD_NUMBER, and STAMP_ARGS.
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Source flutter_build_stamp.sh from a flutter build wrapper; do not execute directly." >&2
  exit 1
fi

eval "$(bash "${MOBILE}/scripts/build_stamp.sh")"

STAMP_ARGS=(
  "--dart-define=BUILD_GIT_SHA=${BUILD_GIT_SHA}"
  "--dart-define=BUILD_NUMBER=${BUILD_NUMBER}"
)
if [[ "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  STAMP_ARGS+=("--build-number=${BUILD_NUMBER}")
fi

echo "Build stamp: git ${BUILD_GIT_SHA}, build ${BUILD_NUMBER}" >&2
