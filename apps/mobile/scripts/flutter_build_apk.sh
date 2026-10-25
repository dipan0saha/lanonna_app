#!/usr/bin/env bash
# The one way to build an APK: `flutter build apk` plus the build stamp
# (BUILD_GIT_SHA / BUILD_NUMBER dart-defines for Crashlytics keys, and
# --build-number for versionCode). All other args pass through, e.g.
#   scripts/flutter_build_apk.sh --debug --split-per-abi --dart-define-from-file=flavors/dev.json
# A prod-flavor APK is Play-bound: it must pass the release guard
# (android_release_guard.sh). Dev APKs are not guarded.
set -euo pipefail

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
cd "${MOBILE}"

# shellcheck source=flutter_build_stamp.sh
source "${MOBILE}/scripts/flutter_build_stamp.sh" apk "$@"

exec flutter build apk "${STAMP_ARGS[@]}" "$@"
