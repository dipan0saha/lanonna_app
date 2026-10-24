#!/usr/bin/env bash
# Opens invite deep link without force-stopping (keeps signed-in session).
set -euo pipefail
TOKEN="${INVITE_TOKEN:-}"
if [[ -z "${TOKEN}" ]]; then
  echo "INVITE_TOKEN is not set" >&2
  exit 1
fi
adb shell am start -a android.intent.action.VIEW \
  -d "lanonna://app/invite-accept?token=${TOKEN}"
