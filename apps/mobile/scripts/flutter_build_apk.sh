#!/usr/bin/env bash
# The one way to build an APK: `flutter build apk` plus the build stamp
# (BUILD_GIT_SHA / BUILD_NUMBER dart-defines for Crashlytics keys, and
# --build-number for versionCode). All other args pass through, e.g.
#   scripts/flutter_build_apk.sh --debug --split-per-abi --dart-define-from-file=flavors/dev.json
# A prod flavor (flavors/prod.json) requires a real stamp and fails otherwise.
set -euo pipefail

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
cd "${MOBILE}"

for arg in "$@"; do
  if [[ "${arg}" == *flavors/prod.json* ]]; then
    export REQUIRE_BUILD_STAMP=1
  fi
done

eval "$(bash "${MOBILE}/scripts/build_stamp.sh")"

STAMP_ARGS=(
  "--dart-define=BUILD_GIT_SHA=${BUILD_GIT_SHA}"
  "--dart-define=BUILD_NUMBER=${BUILD_NUMBER}"
)
if [[ "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  STAMP_ARGS+=("--build-number=${BUILD_NUMBER}")
fi

echo "Build stamp: git ${BUILD_GIT_SHA}, build ${BUILD_NUMBER}" >&2
exec flutter build apk "${STAMP_ARGS[@]}" "$@"
