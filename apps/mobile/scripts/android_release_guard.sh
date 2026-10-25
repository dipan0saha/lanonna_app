#!/usr/bin/env bash
# Release guard for Play-bound Android builds (any AAB, any prod-flavor build).
# Fails loudly unless:
#   1. the working tree is clean (no modified, staged or untracked files);
#   2. HEAD is on origin/main (fetched now, so a stale ref cannot pass);
#   3. the versionCode is strictly greater than every release recorded as an
#      `android-vc-<code>` tag on origin (read with ls-remote, so local tags
#      that were never pushed, or were deleted upstream, do not count).
# The code checked is the one the build will use, so a BUILD_NUMBER override
# passes only when it is higher than the last released code.
# After a build is uploaded to Play, record it with record_android_release.sh.
#
# Usage: android_release_guard.sh <git-root> <version-code>
set -euo pipefail

GIT_ROOT="${1:?usage: android_release_guard.sh <git-root> <version-code>}"
CODE="${2:?usage: android_release_guard.sh <git-root> <version-code>}"
git_() { git -C "${GIT_ROOT}" "$@"; }
fail() { echo "FAIL (release guard): $*" >&2; exit 1; }

[[ "${CODE}" =~ ^[1-9][0-9]*$ ]] || fail "versionCode must be a positive integer, got: ${CODE}"

if [[ -n "$(git_ status --porcelain --untracked-files=normal)" ]]; then
  fail "working tree is not clean; Play builds must be built from a committed tree (git status)"
fi

git_ fetch --quiet origin main 2>/dev/null \
  || fail "could not fetch origin main; the guard needs origin to verify the release"
git_ merge-base --is-ancestor HEAD refs/remotes/origin/main \
  || fail "HEAD $(git_ rev-parse --short HEAD) is not on origin/main; Play builds come from main only"

TAGS="$(git_ ls-remote --tags origin 'refs/tags/android-vc-*' 2>/dev/null)" \
  || fail "could not list android-vc-* tags on origin"
LAST=0
while read -r _ ref; do
  [[ "${ref}" =~ ^refs/tags/android-vc-([1-9][0-9]*)$ ]] || continue
  if ((BASH_REMATCH[1] > LAST)); then LAST="${BASH_REMATCH[1]}"; fi
done <<<"${TAGS}"

if ((CODE <= LAST)); then
  fail "versionCode ${CODE} is not greater than the last released code ${LAST} (tag android-vc-${LAST}). Play rejects it; build from a newer main commit, or set BUILD_NUMBER above ${LAST}."
fi
if ((LAST == 0)); then
  echo "Release guard: no android-vc-* release tag on origin yet (first release); versionCode ${CODE}" >&2
else
  echo "Release guard: versionCode ${CODE} > last released ${LAST}" >&2
fi
