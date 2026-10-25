#!/usr/bin/env bash
# Shared build stamp for flutter_build_apk.sh and flutter_build_appbundle.sh.
# Source it from the wrapper's apps/mobile directory as
#   source flutter_build_stamp.sh <apk|appbundle> "$@"
# It sets BUILD_GIT_SHA, BUILD_NUMBER and STAMP_ARGS. One value feeds Gradle
# versionCode (--build-number) and the BUILD_NUMBER dart-define that Crashlytics
# reports as build_number.
#
# Play-bound builds (every AAB, and every prod-flavor build) export
# ANDROID_RELEASE_BUILD=1, which makes build_stamp.sh run the release guard.
# Prod is detected the way Gradle detects it: APP_ENV from the dart-defines.
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Source flutter_build_stamp.sh from a flutter build wrapper; do not execute directly." >&2
  exit 1
fi

_stamp_artifact="${1:?flutter_build_stamp.sh needs the artifact: apk or appbundle}"
shift

# APP_ENV as Flutter resolves it: --dart-define wins over --dart-define-from-file.
# An unreadable flavor file fails closed rather than silently skipping the guard.
_stamp_env_from_file() {
  if [[ ! -r "$1" ]]; then
    echo "FAIL: cannot read --dart-define-from-file $1" >&2
    exit 1
  fi
  sed -n 's/.*"APP_ENV"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1
}
_stamp_app_env=""
_stamp_file_env=""
_stamp_next_is_file=0
for _stamp_arg in "$@"; do
  if ((_stamp_next_is_file)); then
    _stamp_file_env="$(_stamp_env_from_file "${_stamp_arg}")" || exit 1
    _stamp_next_is_file=0
    continue
  fi
  case "${_stamp_arg}" in
    --dart-define-from-file=*) _stamp_file_env="$(_stamp_env_from_file "${_stamp_arg#*=}")" || exit 1 ;;
    --dart-define-from-file) _stamp_next_is_file=1 ;;
    --dart-define=APP_ENV=*) _stamp_app_env="${_stamp_arg#--dart-define=APP_ENV=}" ;;
  esac
done
_stamp_app_env="${_stamp_app_env:-${_stamp_file_env}}"

if [[ "${_stamp_artifact}" == "appbundle" || "${_stamp_app_env}" == "prod" ]]; then
  export ANDROID_RELEASE_BUILD=1
fi

eval "$(bash "${MOBILE}/scripts/build_stamp.sh")"

STAMP_ARGS=(
  "--dart-define=BUILD_GIT_SHA=${BUILD_GIT_SHA}"
  "--dart-define=BUILD_NUMBER=${BUILD_NUMBER}"
)
if [[ "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  STAMP_ARGS+=("--build-number=${BUILD_NUMBER}")
fi

echo "Build stamp: git ${BUILD_GIT_SHA}, versionCode/build ${BUILD_NUMBER}" >&2
