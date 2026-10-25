#!/usr/bin/env bash
# The one way to build an AAB: `flutter build appbundle` plus the same build stamp
# as flutter_build_apk.sh (versionCode and Crashlytics dart-defines).
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

exec flutter build appbundle "${STAMP_ARGS[@]}" "$@"
