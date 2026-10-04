#!/usr/bin/env bash
# Read the latest App Check debug UUID from logcat and register it in Firebase.
set -euo pipefail

APP_ID="1:1008830071001:android:0144f51dbc29e9a94abec8"
PROJECT="lanonna-dev"

read_token() {
  adb logcat -d 2>/dev/null \
    | rg -o 'Firebase App Check debug token: [a-f0-9-]+' \
    | tail -1 \
    | sed 's/.*: //' || true
}

TOKEN=""
for _ in $(seq 1 45); do
  TOKEN="$(read_token)"
  if [[ -n "${TOKEN}" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "${TOKEN}" ]]; then
  echo "No App Check debug token in logcat after waiting. Launch the app and check App Check debug provider." >&2
  exit 1
fi

echo "Registering App Check debug token: ${TOKEN}"
firebase appcheck:debugtokens:create "${TOKEN}" \
  --app "${APP_ID}" \
  --project "${PROJECT}" \
  --force
