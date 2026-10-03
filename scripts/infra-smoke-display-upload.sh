#!/usr/bin/env bash
# Smoke: signed URL (API) → PUT to GCS display bucket → Pub/Sub → worker logs.
set -euo pipefail

API_BASE="${API_BASE_URL:-https://api-1008830071001.us-central1.run.app}"
PROJECT="${GCP_PROJECT_ID:-lanonna-dev}"
FIREBASE_API_KEY="${FIREBASE_API_KEY:-}"
TEST_EMAIL="${SMOKE_TEST_EMAIL:-lanonna.dev.smoke@test.com}"
TEST_PASSWORD="${SMOKE_TEST_PASSWORD:-}"
SMOKE_CREDS_FILE="${SMOKE_CREDS_FILE:-}"

if [[ -z "${TEST_PASSWORD}" && -n "${SMOKE_CREDS_FILE}" && -f "${SMOKE_CREDS_FILE}" ]]; then
  TEST_EMAIL="$(grep '^email=' "${SMOKE_CREDS_FILE}" | cut -d= -f2-)"
  TEST_PASSWORD="$(grep '^password=' "${SMOKE_CREDS_FILE}" | cut -d= -f2-)"
fi

if [[ -z "${FIREBASE_API_KEY}" ]]; then
  FIREBASE_API_KEY="$(python3 -c "import re; print(re.search(r\"apiKey: '([^']+)'\", open('apps/mobile/lib/firebase_options.dart').read()).group(1))")"
fi

if [[ -z "${TEST_PASSWORD}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD for ${TEST_EMAIL}" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "1) Firebase sign-in…"
ID_TOKEN="$(curl -sS "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\",\"returnSecureToken\":true}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['idToken'])")"

echo "2) Mint signed upload URL…"
SIGN_JSON="$(curl -sS -X POST "${API_BASE}/v1/uploads/display/signed-url" \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"content_type":"image/jpeg","byte_length":200}')"
echo "${SIGN_JSON}" | python3 -m json.tool

UPLOAD_URL="$(echo "${SIGN_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['upload_url'])")"
OBJECT_PATH="$(echo "${SIGN_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['object_path'])")"

echo "3) PUT object to GCS…"
TMP_JPEG="$(mktemp)"
python3 -c "open('${TMP_JPEG}','wb').write(bytes([0xFF,0xD8,0xFF,0xE0,0x00,0x10,0x4A,0x46,0x49,0x46,0x00,0x01,0x01,0x00,0x00,0x01,0x00,0x01,0x00,0x00,0xFF,0xDB,0x00,0x43,0x00,0x08,0x06,0x06,0x07,0x06,0x05,0x08,0x07,0x07,0x07,0x09,0x09,0x08,0x0A,0x0C,0x14,0x0D,0x0C,0x0B,0x0B,0x0C,0x19,0x12,0x13,0x0F,0x14,0x1D,0x1A,0x1F,0x1E,0x1D,0x1A,0x1C,0x1C,0x20,0x24,0x2E,0x27,0x20,0x22,0x2C,0x23,0x1C,0x1C,0x28,0x37,0x29,0x2C,0x30,0x31,0x34,0x34,0x34,0x1F,0x27,0x39,0x3D,0x38,0x32,0x3C,0x2E,0x33,0x34,0x32,0xFF,0xC0,0x00,0x0B,0x08,0x00,0x01,0x00,0x01,0x01,0x01,0x11,0x00,0xFF,0xC4,0x00,0x1F,0x00,0x00,0x01,0x05,0x01,0x01,0x01,0x01,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0xFF,0xDA,0x00,0x08,0x01,0x01,0x00,0x00,0x3F,0x00,0xFB,0xD5,0x47,0xFF,0xD9]))"
curl -sS -o /dev/null -w "HTTP %{http_code}\n" -X PUT "${UPLOAD_URL}" \
  -H 'Content-Type: image/jpeg' \
  -H 'x-goog-content-length-range: 0,2097152' \
  --data-binary @"${TMP_JPEG}"
rm -f "${TMP_JPEG}"

echo "4) Wait for Pub/Sub → worker…"
sleep 12
echo "5) Worker logs (gcs_object_finalized)…"
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=worker AND textPayload:gcs_object_finalized AND textPayload:${OBJECT_PATH##*/}" \
  --project="${PROJECT}" \
  --limit=3 \
  --freshness=5m \
  --format='value(textPayload)'

echo "6) GCS object exists…"
gcloud storage ls "gs://lanonna-dev-display/${OBJECT_PATH}" --project="${PROJECT}"

echo "Smoke complete: ${OBJECT_PATH}"
