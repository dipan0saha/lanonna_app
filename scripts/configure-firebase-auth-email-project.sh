#!/usr/bin/env bash
# One-time / per-machine setup so Identity Toolkit + Firebase Management API calls bill quota correctly.
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
DISPLAY_NAME="${FIREBASE_DISPLAY_NAME:-La Nonna}"

echo "Setting Application Default Credentials quota project to ${PROJECT_ID}..."
gcloud auth application-default set-quota-project "${PROJECT_ID}"

echo "Setting GCP project display name to ${DISPLAY_NAME}..."
gcloud projects update "${PROJECT_ID}" --name="${DISPLAY_NAME}"

TOKEN="$(gcloud auth print-access-token --project="${PROJECT_ID}")"
echo "Setting Firebase console display name to ${DISPLAY_NAME}..."
curl -sS -f -X PATCH \
  "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}?updateMask=displayName" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  -d "{\"displayName\":\"${DISPLAY_NAME}\"}" >/dev/null

echo "Done. Run: bash scripts/sync-firebase-auth-templates.sh apply"
