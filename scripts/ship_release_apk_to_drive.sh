#!/usr/bin/env bash
# Build release APK (dev flavor) and copy to Google Drive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="${ROOT}/apps/mobile"
cd "${MOBILE}"

echo "Building release APK..."
eval "$(bash scripts/build_stamp.sh)"
flutter build apk --release \
  --build-number="${BUILD_NUMBER}" \
  --dart-define=BUILD_GIT_SHA="${BUILD_GIT_SHA}" \
  --dart-define=BUILD_NUMBER="${BUILD_NUMBER}" \
  --dart-define-from-file=flavors/dev.json
"${ROOT}/scripts/copy_release_apk_to_drive.sh"
