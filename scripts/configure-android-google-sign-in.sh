#!/usr/bin/env bash
# One-time dev setup: Android debug SHA + refresh google-services.json for Google Sign-In.
set -euo pipefail

PROJECT="${GCP_PROJECT_ID:-lanonna-dev}"
APP_ID="1:1008830071001:android:0144f51dbc29e9a94abec8"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/apps/mobile/android/app/google-services.json"

SHA1="$(keytool -list -v -keystore "${HOME}/.android/debug.keystore" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | awk '/SHA1:/ {print $2}')"

echo "Project: ${PROJECT}"
echo "Debug SHA-1: ${SHA1}"
echo ""
echo "If Google Sign-In still fails, enable it once in Firebase:"
echo "  https://console.firebase.google.com/project/${PROJECT}/authentication/providers"
echo "  → Google → Enable → Save"
echo ""

if [[ -n "${SHA1}" ]]; then
  firebase apps:android:sha:create "${APP_ID}" "${SHA1}" --project "${PROJECT}" 2>/dev/null || true
fi

firebase apps:sdkconfig ANDROID "${APP_ID}" --project "${PROJECT}" -o "${OUT}"

OAUTH_COUNT="$(python3 -c "import json; d=json.load(open('${OUT}')); print(len(d['client'][0].get('oauth_client',[])))")"
echo "Wrote ${OUT} (oauth_client entries: ${OAUTH_COUNT})"

if [[ "${OAUTH_COUNT}" == "0" ]]; then
  echo "oauth_client is still empty — enable Google in Firebase Console (link above), then re-run this script."
  exit 1
fi

WEB_ID="$(python3 -c "
import json
d=json.load(open('${OUT}'))
for c in d['client'][0].get('oauth_client',[]):
    if c.get('client_type')==3:
        print(c['client_id']); break
")"
if [[ -n "${WEB_ID}" ]]; then
  echo "Web client ID (serverClientId): ${WEB_ID}"
  echo "Add to apps/mobile/flavors/dev.json as GOOGLE_SIGN_IN_SERVER_CLIENT_ID if not already set."
fi
