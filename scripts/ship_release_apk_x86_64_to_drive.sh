#!/usr/bin/env bash
# Build x86_64 release APK (Android emulator) and copy to Google Drive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="${ROOT}/apps/mobile"
cd "${MOBILE}"

echo "Building x86_64 release APK..."
flutter build apk --release \
  --target-platform android-x64 \
  --dart-define-from-file=flavors/dev.json

"${ROOT}/scripts/copy_release_apk_to_drive.sh" lanonna_app_x86_64.apk
