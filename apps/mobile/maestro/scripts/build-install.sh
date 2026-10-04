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

if ((${#EXTRA_DEFINES[@]} > 0)); then
  flutter build apk --debug \
    --dart-define-from-file=flavors/dev.json \
    --split-per-abi \
    "${EXTRA_DEFINES[@]}"
else
  flutter build apk --debug \
    --dart-define-from-file=flavors/dev.json \
    --split-per-abi
fi

ABI="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
APK="build/app/outputs/flutter-apk/app-${ABI}-debug.apk"
if [[ ! -f "${APK}" ]]; then
  echo "APK not found for ABI ${ABI}: ${APK}" >&2
  exit 1
fi

adb shell pm trim-caches 800M >/dev/null 2>&1 || true
adb uninstall com.lanonna.lanonna >/dev/null 2>&1 || true
adb install -r "${APK}"
