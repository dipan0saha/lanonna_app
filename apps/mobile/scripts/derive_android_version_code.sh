#!/usr/bin/env bash
# Derives a monotonic Android versionCode (BUILD_NUMBER / --build-number) from HEAD.
# Same commit always yields the same integer; squash merges cannot lower it vs the branch build.
# See docs/engineering/rca/issue-444-build-number-regression.md
set -euo pipefail

# Seconds since 2020-01-01T00:00:00Z — headroom under Play's 2_100_000_000 cap through ~2086.
readonly ANDROID_VERSION_EPOCH="${ANDROID_VERSION_EPOCH:-1577836800}"
# Above legacy git rev-list counts (~239–241 on installed dev builds).
readonly ANDROID_VERSION_CODE_FLOOR="${ANDROID_VERSION_CODE_FLOOR:-300}"
readonly ANDROID_VERSION_CODE_MAX=2100000000

if [[ -n "${BUILD_NUMBER:-}" ]]; then
  NUMBER="${BUILD_NUMBER}"
else
  GIT_ROOT="${1:-}"
  if [[ -z "${GIT_ROOT}" ]]; then
    echo "derive_android_version_code.sh: git root path required" >&2
    exit 1
  fi
  COMMIT_TS="$(git -C "${GIT_ROOT}" log -1 --format=%ct HEAD 2>/dev/null || true)"
  if [[ -z "${COMMIT_TS}" || ! "${COMMIT_TS}" =~ ^[0-9]+$ ]]; then
    exit 2
  fi
  NUMBER=$((COMMIT_TS - ANDROID_VERSION_EPOCH))
  if ((NUMBER < ANDROID_VERSION_CODE_FLOOR)); then
    NUMBER="${ANDROID_VERSION_CODE_FLOOR}"
  fi
fi

if [[ ! "${NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "FAIL: BUILD_NUMBER must be a non-negative integer, got: ${NUMBER}" >&2
  exit 1
fi
if ((NUMBER > ANDROID_VERSION_CODE_MAX)); then
  echo "FAIL: versionCode ${NUMBER} exceeds Play maximum ${ANDROID_VERSION_CODE_MAX}" >&2
  exit 1
fi

printf '%s\n' "${NUMBER}"
