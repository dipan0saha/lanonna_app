#!/usr/bin/env bash
# Prints the Android versionCode (BUILD_NUMBER / --build-number) for a commit:
# seconds from 2020-01-01T00:00:00Z to the commit's committer time. Same commit,
# same code; a squash merge commits later than the branch it merges, so main's
# code is higher than the branch tip's. Committer time is NOT strictly monotonic
# (clock skew, cherry-picks, rewritten dates), so Play-bound builds are also
# checked against the last released code by android_release_guard.sh.
# See docs/engineering/rca/issue-444-build-number-regression.md
#
# Usage: derive_android_version_code.sh <git-root> [rev]   (rev defaults to HEAD)
# A non-empty BUILD_NUMBER in the environment replaces the derived value.
# Exit: 0 printed a code; 2 git or the commit is unavailable; 1 invalid value.
set -euo pipefail

readonly EPOCH=1577836800       # 2020-01-01T00:00:00Z; changing it renumbers every build
readonly PLAY_MAX=2100000000    # Play's versionCode ceiling (reached in 2086)

if [[ -n "${BUILD_NUMBER:-}" ]]; then
  NUMBER="${BUILD_NUMBER}"
else
  GIT_ROOT="${1:?usage: derive_android_version_code.sh <git-root> [rev]}"
  COMMIT_TS="$(git -C "${GIT_ROOT}" log -1 --format=%ct "${2:-HEAD}" 2>/dev/null || true)"
  if [[ ! "${COMMIT_TS}" =~ ^[0-9]+$ ]]; then
    exit 2
  fi
  NUMBER=$((COMMIT_TS - EPOCH))
fi

# Positive decimal with no leading zero (bash would read 0123 as octal), at most 10 digits.
if [[ ! "${NUMBER}" =~ ^[1-9][0-9]{0,9}$ ]]; then
  echo "FAIL: versionCode must be a positive integer without leading zeros, got: ${NUMBER}" >&2
  exit 1
fi
if ((NUMBER > PLAY_MAX)); then
  echo "FAIL: versionCode ${NUMBER} exceeds Play maximum ${PLAY_MAX}" >&2
  exit 1
fi

printf '%s\n' "${NUMBER}"
