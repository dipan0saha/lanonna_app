#!/usr/bin/env bash
# Prints `export BUILD_GIT_SHA=... BUILD_NUMBER=...` for the build stamp.
# Build Android binaries with flutter_build_apk.sh / flutter_build_appbundle.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

GIT_SHA="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
if [[ -z "${GIT_SHA}" ]]; then
  GIT_SHA="unknown"
fi

NUMBER="unknown"
if DERIVED="$(bash "$(dirname "$0")/derive_android_version_code.sh" "${ROOT}" 2>/dev/null)"; then
  NUMBER="${DERIVED}"
fi

# flutter_build_*.sh sets REQUIRE_BUILD_STAMP=1 for the prod flavor.
if [[ "${REQUIRE_BUILD_STAMP:-}" == "1" ]]; then
  if [[ "${GIT_SHA}" == "unknown" ]]; then
    echo "FAIL: BUILD_GIT_SHA is required for prod release (git not available?)" >&2
    exit 1
  fi
  if [[ "${NUMBER}" == "unknown" ]]; then
    echo "FAIL: BUILD_NUMBER is required for prod release (could not derive versionCode from git?)" >&2
    exit 1
  fi
fi

printf 'export BUILD_GIT_SHA=%q\n' "${GIT_SHA}"
printf 'export BUILD_NUMBER=%q\n' "${NUMBER}"
