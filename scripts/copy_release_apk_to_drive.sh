#!/usr/bin/env bash
# Copy the built release APK to Google Drive (overwrites the destination file).
# Usage: copy_release_apk_to_drive.sh [drive_file_name]   (default: lanonna_app.apk)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${ROOT}/apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
DRIVE_DIR="${LANONNA_DRIVE_DIR:-$HOME/Library/CloudStorage/GoogleDrive-dipan.saha@gmail.com/My Drive/Online Library/Apps/Current Work/LaNonna}"
DEST_NAME="${1:-lanonna_app.apk}"

if [[ ! -f "${APK}" ]]; then
  echo "Release APK not found. Build it first: scripts/ship_release_apk_to_drive.sh or scripts/ship_release_apk_x86_64_to_drive.sh"
  exit 1
fi

mkdir -p "${DRIVE_DIR}"
cp -f "${APK}" "${DRIVE_DIR}/${DEST_NAME}"
echo "Shipped to:"
echo "  ${DRIVE_DIR}/${DEST_NAME}"
ls -lh "${DRIVE_DIR}/${DEST_NAME}"
