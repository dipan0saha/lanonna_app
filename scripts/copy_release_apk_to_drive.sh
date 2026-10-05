#!/usr/bin/env bash
# Copy built release APK to Google Drive (overwrites lanonna_app.apk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${ROOT}/apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
DRIVE_DIR="${LANONNA_DRIVE_DIR:-$HOME/Library/CloudStorage/GoogleDrive-dipan.saha@gmail.com/My Drive/Online Library/Apps/Current Work/LaNonna}"

if [[ ! -f "${APK}" ]]; then
  echo "Release APK not found. Run: scripts/ship_release_apk_to_drive.sh"
  exit 1
fi

mkdir -p "${DRIVE_DIR}"
cp -f "${APK}" "${DRIVE_DIR}/lanonna_app.apk"
echo "Shipped to:"
echo "  ${DRIVE_DIR}/lanonna_app.apk"
ls -lh "${DRIVE_DIR}/lanonna_app.apk"
