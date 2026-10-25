#!/usr/bin/env bash
# The one way to build an AAB: `flutter build appbundle` plus the same build stamp
# as flutter_build_apk.sh. An AAB only exists to go to Play, so every AAB (any
# flavor) must pass the release guard: clean tree, HEAD on origin/main, and a
# versionCode above the last android-vc-* release tag. After Play accepts the
# upload, record it: scripts/record_android_release.sh <versionCode>.
set -euo pipefail

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
cd "${MOBILE}"

# shellcheck source=flutter_build_stamp.sh
source "${MOBILE}/scripts/flutter_build_stamp.sh" appbundle "$@"

exec flutter build appbundle "${STAMP_ARGS[@]}" "$@"
