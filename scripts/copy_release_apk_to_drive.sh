#!/usr/bin/env bash
# Copy built release APK to Google Drive (lanonna_app.apk + versioned copy).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${ROOT}/apps/mobile/build/app/outputs/flutter-apk/app-release.apk"
DRIVE_DIR="${LANONNA_DRIVE_DIR:-$HOME/Library/CloudStorage/GoogleDrive-dipan.saha@gmail.com/My Drive/Online Library/Apps/Current Work/LaNonna}"

if [[ ! -f "${APK}" ]]; then
  echo "Release APK not found. Run: scripts/ship_release_apk_to_drive.sh"
  exit 1
fi

VERSION="$(grep '^version:' "${ROOT}/apps/mobile/pubspec.yaml" | awk '{print $2}')"
HASH="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo local)"
DATE="$(date +%Y%m%d)"
VERSIONED="lanonna-dev-${VERSION}-${HASH}-${DATE}.apk"

mkdir -p "${DRIVE_DIR}"
cp -f "${APK}" "${DRIVE_DIR}/lanonna_app.apk"
cp -f "${APK}" "${DRIVE_DIR}/${VERSIONED}"
echo "Shipped to:"
echo "  ${DRIVE_DIR}/lanonna_app.apk"
echo "  ${DRIVE_DIR}/${VERSIONED}"
ls -lh "${DRIVE_DIR}/lanonna_app.apk"
