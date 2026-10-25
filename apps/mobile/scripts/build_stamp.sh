#!/usr/bin/env bash
# Prints `export BUILD_GIT_SHA=... BUILD_NUMBER=...` for the build stamp.
# Build Android binaries with flutter_build_apk.sh / flutter_build_appbundle.sh,
# which apply it. With ANDROID_RELEASE_BUILD=1 (Play-bound: any AAB or prod
# flavor) both values are required and android_release_guard.sh must pass.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPTS}/../../.." && pwd)"

GIT_SHA="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
if [[ -z "${GIT_SHA}" ]]; then
  GIT_SHA="unknown"
fi

# Exit 2 means no git: dev builds still build, stamped `unknown`. An invalid
# BUILD_NUMBER override (exit 1) always fails.
if NUMBER="$(bash "${SCRIPTS}/derive_android_version_code.sh" "${ROOT}")"; then
  :
else
  rc=$?
  [[ ${rc} -eq 2 ]] || exit "${rc}"
  NUMBER="unknown"
fi

if [[ "${ANDROID_RELEASE_BUILD:-}" == "1" ]]; then
  if [[ "${GIT_SHA}" == "unknown" ]]; then
    echo "FAIL: BUILD_GIT_SHA is required for a Play-bound build (git not available?)" >&2
    exit 1
  fi
  if [[ "${NUMBER}" == "unknown" ]]; then
    echo "FAIL: BUILD_NUMBER is required for a Play-bound build (could not derive versionCode from git?)" >&2
    exit 1
  fi
  bash "${SCRIPTS}/android_release_guard.sh" "${ROOT}" "${NUMBER}"
fi

printf 'export BUILD_GIT_SHA=%q\n' "${GIT_SHA}"
printf 'export BUILD_NUMBER=%q\n' "${NUMBER}"
