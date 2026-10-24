#!/usr/bin/env bash
# Build release APK (dev flavor) and copy to Google Drive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="${ROOT}/apps/mobile"
cd "${MOBILE}"

echo "Building release APK..."
scripts/flutter_build_apk.sh --release \
  --dart-define-from-file=flavors/dev.json
"${ROOT}/scripts/copy_release_apk_to_drive.sh"
