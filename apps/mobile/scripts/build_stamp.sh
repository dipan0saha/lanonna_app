#!/usr/bin/env bash
# Prints `export BUILD_GIT_SHA=... BUILD_NUMBER=...` for the build stamp.
# Build APKs with scripts/flutter_build_apk.sh, which applies it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

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

# flutter_build_apk.sh sets REQUIRE_BUILD_STAMP=1 for the prod flavor.
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
