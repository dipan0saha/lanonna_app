#!/usr/bin/env bash
# Build x86_64 release APK (Android emulator) and copy to Google Drive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="${ROOT}/apps/mobile"
APK="${MOBILE}/build/app/outputs/flutter-apk/app-release.apk"
DRIVE_DIR="${LANONNA_DRIVE_DIR:-$HOME/Library/CloudStorage/GoogleDrive-dipan.saha@gmail.com/My Drive/Online Library/Apps/Current Work/LaNonna}"

cd "${MOBILE}"

echo "Building x86_64 release APK..."
flutter build apk --release \
  --target-platform android-x64 \
  --dart-define-from-file=flavors/dev.json

if [[ ! -f "${APK}" ]]; then
  echo "Expected APK not found: ${APK}"
  exit 1
fi

mkdir -p "${DRIVE_DIR}"
cp -f "${APK}" "${DRIVE_DIR}/lanonna_app_x86_64.apk"
echo "Shipped to:"
echo "  ${DRIVE_DIR}/lanonna_app_x86_64.apk"
ls -lh "${DRIVE_DIR}/lanonna_app_x86_64.apk"
