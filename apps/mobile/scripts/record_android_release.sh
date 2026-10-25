#!/usr/bin/env bash
# Records an Android versionCode as released, after the AAB built from HEAD was
# accepted by Play: creates and pushes the annotated tag android-vc-<code> on
# HEAD. android_release_guard.sh refuses any later Play build whose code is not
# higher. Run it from the same clean main checkout that built the AAB.
#
# Usage: apps/mobile/scripts/record_android_release.sh <version-code>
set -euo pipefail

CODE="${1:?usage: record_android_release.sh <version-code>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Same preconditions as the build: clean tree, HEAD on origin/main, code above
# every recorded release.
bash "$(dirname "$0")/android_release_guard.sh" "${ROOT}" "${CODE}"

TAG="android-vc-${CODE}"
SHA="$(git -C "${ROOT}" rev-parse --short HEAD)"
git -C "${ROOT}" tag -a "${TAG}" -m "Android versionCode ${CODE} released to Play from ${SHA}"
if ! git -C "${ROOT}" push --quiet origin "refs/tags/${TAG}"; then
  echo "FAIL: created ${TAG} locally but could not push it; run: git push origin refs/tags/${TAG}" >&2
  exit 1
fi
echo "Recorded ${TAG} on ${SHA}"
