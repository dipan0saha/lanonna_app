#!/usr/bin/env bash
# Emits BUILD_GIT_SHA and BUILD_NUMBER for flutter build (Crashlytics keys + versionCode).
# Source from release scripts: eval "$(bash scripts/build_stamp.sh)"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

GIT_SHA="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
if [[ -z "${GIT_SHA}" ]]; then
  GIT_SHA="unknown"
fi

if [[ -n "${BUILD_NUMBER:-}" ]]; then
  NUMBER="${BUILD_NUMBER}"
elif [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
  NUMBER="${GITHUB_RUN_NUMBER}"
else
  NUMBER="$(git -C "${ROOT}" rev-list --count HEAD 2>/dev/null || true)"
fi
if [[ -z "${NUMBER}" ]]; then
  NUMBER="unknown"
fi

# Prod release callers must export REQUIRE_BUILD_STAMP=1 to fail fast.
if [[ "${REQUIRE_BUILD_STAMP:-}" == "1" ]]; then
  if [[ "${GIT_SHA}" == "unknown" ]]; then
    echo "FAIL: BUILD_GIT_SHA is required for prod release (git not available?)" >&2
    exit 1
  fi
  if [[ "${NUMBER}" == "unknown" ]]; then
    echo "FAIL: BUILD_NUMBER is required for prod release" >&2
    exit 1
  fi
fi

printf 'export BUILD_GIT_SHA=%q\n' "${GIT_SHA}"
printf 'export BUILD_NUMBER=%q\n' "${NUMBER}"
