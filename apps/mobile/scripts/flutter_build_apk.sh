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

# shellcheck source=flutter_build_stamp.sh
source "${MOBILE}/scripts/flutter_build_stamp.sh"

exec flutter build apk "${STAMP_ARGS[@]}" "$@"
