#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

EXTRA_DEFINES=()
if [[ "${MAESTRO_AUTO_LOGIN:-}" == "1" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/maestro/scripts/load-env.sh"
  if [[ -z "${SMOKE_TEST_EMAIL:-}" || -z "${SMOKE_TEST_PASSWORD:-}" ]]; then
    echo "MAESTRO_AUTO_LOGIN=1 requires SMOKE_TEST_EMAIL and SMOKE_TEST_PASSWORD in maestro/local.env" >&2
    exit 1
  fi
  EXTRA_DEFINES+=(
    "--dart-define=DEV_AUTO_SIGN_IN_EMAIL=${SMOKE_TEST_EMAIL}"
    "--dart-define=DEV_AUTO_SIGN_IN_PASSWORD=${SMOKE_TEST_PASSWORD}"
  )
fi
EXTRA_DEFINES+=("--dart-define=MAESTRO_SEMANTICS=true")

# One ABI via --target-platform (not --split-per-abi), so versionCode stays the
# build stamp's BUILD_NUMBER.
ABI="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
case "${ABI}" in
  arm64-v8a) PLATFORM="android-arm64" ;;
  x86_64) PLATFORM="android-x64" ;;
  armeabi-v7a) PLATFORM="android-arm" ;;
  *) echo "Unsupported device ABI: ${ABI}" >&2; exit 1 ;;
esac

"${ROOT}/scripts/flutter_build_apk.sh" --debug \
  --dart-define-from-file=flavors/dev.json \
  --target-platform "${PLATFORM}" \
  "${EXTRA_DEFINES[@]}"

APK="build/app/outputs/flutter-apk/app-debug.apk"
if [[ ! -f "${APK}" ]]; then
  echo "APK not found: ${APK}" >&2
  exit 1
fi

adb shell pm trim-caches 800M >/dev/null 2>&1 || true
# Upgrade in place so App Check debug secret (and other app data) survives rebuilds.
adb install -r "${APK}"
