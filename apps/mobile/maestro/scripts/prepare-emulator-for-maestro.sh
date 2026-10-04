#!/usr/bin/env bash
# Launch app, register App Check debug token from logcat, relaunch so API calls work.
# Set MAESTRO_PREPARE_CLEAR=0 to skip `pm clear` (e.g. warm session).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
chmod +x "${ROOT}/maestro/scripts/register-app-check-debug.sh"

if [[ "${MAESTRO_PREPARE_CLEAR:-1}" == "1" ]]; then
  echo "Clearing app data and priming App Check debug token…"
  adb shell pm clear com.lanonna.lanonna
  adb logcat -c
else
  echo "Priming App Check debug token (keeping app data)…"
  adb logcat -c
fi

_prime_app_check() {
  adb shell am force-stop com.lanonna.lanonna || true
  sleep 1
  adb shell am start -n com.lanonna.lanonna/.MainActivity
  sleep 5
  "${ROOT}/maestro/scripts/register-app-check-debug.sh"
}

if ! _prime_app_check; then
  echo "Retrying App Check debug token registration…" >&2
  adb logcat -c
  _prime_app_check
fi

adb shell am force-stop com.lanonna.lanonna
sleep 2
adb shell am start -n com.lanonna.lanonna/.MainActivity
sleep 15
