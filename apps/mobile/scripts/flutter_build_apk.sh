#!/usr/bin/env bash
# The one way to build an APK: `flutter build apk` plus the build stamp
# (BUILD_GIT_SHA / BUILD_NUMBER dart-defines for Crashlytics keys, and
# --build-number for versionCode). All other args pass through, e.g.
#   scripts/flutter_build_apk.sh --debug --target-platform android-arm64 --dart-define-from-file=flavors/dev.json
# --split-per-abi is refused: Flutter rewrites each split's versionCode to
# abi*1000 + code, so it would no longer equal BUILD_NUMBER (Crashlytics) and
# a split and a universal APK could collide. Use --target-platform instead.
# A prod-flavor APK is Play-bound: it must pass the release guard
# (android_release_guard.sh). Dev APKs are not guarded.
set -euo pipefail

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
cd "${MOBILE}"

for arg in "$@"; do
  if [[ "${arg}" == "--split-per-abi" ]]; then
    echo "FAIL: --split-per-abi changes versionCode to abi*1000+code; build one ABI with --target-platform instead" >&2
    exit 1
  fi
done

# shellcheck source=flutter_build_stamp.sh
source "${MOBILE}/scripts/flutter_build_stamp.sh" apk "$@"

exec flutter build apk "${STAMP_ARGS[@]}" "$@"
