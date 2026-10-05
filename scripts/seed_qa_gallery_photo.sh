#!/usr/bin/env bash
# Create gallery photos for the QA owner baby via signed upload + worker.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="${REPO_ROOT}/apps/mobile"
# shellcheck disable=SC1091
source "${MOBILE}/maestro/scripts/load-env.sh"

API_BASE="${API_BASE_URL:-https://api-r27szgit5q-uc.a.run.app}"
QA_OWNER_EMAIL="${QA_OWNER_EMAIL:-lanonna.dev.qa.owner@test.com}"
QA_FOLLOWER_EMAIL="${QA_FOLLOWER_EMAIL:-lanonna.dev.qa.follower@test.com}"
QA_TEST_PASSWORD="${QA_TEST_PASSWORD:-${SMOKE_TEST_PASSWORD:-}}"
FIXTURES="${MAESTRO_FIXTURES_OUT:-${MOBILE}/maestro/.qa-fixtures.env}"
COUNT="${QA_GALLERY_PHOTO_COUNT:-5}"
SAMPLES_DIR="${QA_GALLERY_SAMPLES_DIR:-${REPO_ROOT}/emulator_testing/sample_photos}"

if [[ -z "${QA_TEST_PASSWORD}" ]]; then
  echo "Set SMOKE_TEST_PASSWORD in maestro/local.env" >&2
  exit 1
fi

if [[ ! -f "${FIXTURES}" ]]; then
  echo "Missing ${FIXTURES}; run provision_qa_validation_accounts.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${FIXTURES}"
BABY_ID="${baby_profile_id:-}"

if [[ -z "${BABY_ID}" ]]; then
  echo "baby_profile_id not in ${FIXTURES}" >&2
  exit 1
fi

export QA_BABY_PROFILE_ID="${BABY_ID}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5433}"
if [[ -z "${DB_PASSWORD:-}" && -z "${PGPASSWORD:-}" ]]; then
  if command -v gcloud >/dev/null 2>&1; then
    export PGPASSWORD
    PGPASSWORD="$(gcloud secrets versions access latest \
      --secret=db-lanonna-app-password \
      --project=lanonna-dev 2>/dev/null || true)"
    [[ -n "${PGPASSWORD}" ]] && export DB_PASSWORD="${PGPASSWORD}"
  fi
fi

PROVISION_PY="${PYTHON:-python3}"
if [[ -x "${REPO_ROOT}/services/api/.venv/bin/python" ]]; then
  PROVISION_PY="${REPO_ROOT}/services/api/.venv/bin/python"
fi

echo "Clearing old gallery rows (fake SQL + broken seeds)…"
cd "${REPO_ROOT}/infra/db"
"${PROVISION_PY}" provision_maestro_fixtures.py qa_cleanup_gallery

FIREBASE_API_KEY="$(python3 -c "import re; print(re.search(r\"apiKey: '([^']+)'\", open('${MOBILE}/lib/firebase_options.dart').read()).group(1))")"

sign_in() {
  local email=$1
  curl -sS "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${QA_TEST_PASSWORD}\",\"returnSecureToken\":true}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['idToken'])"
}

echo "Sign-in ${QA_OWNER_EMAIL}…"
OWNER_TOKEN="$(sign_in "${QA_OWNER_EMAIL}")"

PHOTO_FILES=(
  "${SAMPLES_DIR}/qa_ultrasound.jpg"
  "${SAMPLES_DIR}/qa_nursery.jpg"
  "${SAMPLES_DIR}/qa_family.jpg"
  "${SAMPLES_DIR}/qa_baby_bump.jpg"
  "${SAMPLES_DIR}/qa_shower.jpg"
)
CAPTIONS=(
  "QA gallery - ultrasound"
  "QA gallery - nursery prep"
  "QA gallery - family visit"
  "QA gallery - baby bump"
  "QA gallery - shower day"
)

if (( COUNT > ${#PHOTO_FILES[@]} )); then
  echo "QA_GALLERY_PHOTO_COUNT=${COUNT} exceeds ${#PHOTO_FILES[@]} sample file(s)." >&2
  exit 1
fi
for ((i = 0; i < COUNT; i++)); do
  if [[ ! -f "${PHOTO_FILES[$i]}" ]]; then
    echo "Missing sample: ${PHOTO_FILES[$i]}" >&2
    exit 1
  fi
done

FIRST_PHOTO_ID=""
echo "Uploading ${COUNT} sample photo(s) for baby ${BABY_ID}…"
for ((i = 0; i < COUNT; i++)); do
  CAPTION="${CAPTIONS[$i]:-QA gallery sample $((i + 1))}"
  TMP_JPEG="${PHOTO_FILES[$i]}"
  BYTE_LEN="$(wc -c < "${TMP_JPEG}" | tr -d ' ')"

  INIT_JSON="$(curl -sS -X POST "${API_BASE}/v1/photos/init" \
    -H "Authorization: Bearer ${OWNER_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"baby_profile_id\":\"${BABY_ID}\",\"content_type\":\"image/jpeg\",\"byte_length\":${BYTE_LEN},\"caption\":\"${CAPTION}\"}")"

  UPLOAD_URL="$(echo "${INIT_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['upload_url'])")"
  PHOTO_ID="$(echo "${INIT_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['photo_id'])")"
  [[ -z "${FIRST_PHOTO_ID}" ]] && FIRST_PHOTO_ID="${PHOTO_ID}"

  curl -sS -o /dev/null -w "  ${CAPTION}: PUT %{http_code}\n" -X PUT "${UPLOAD_URL}" \
    -H 'Content-Type: image/jpeg' \
    -H 'x-goog-content-length-range: 0,2097152' \
    --data-binary @"${TMP_JPEG}"
  echo "    photo_id=${PHOTO_ID}"
  sleep 2
done

echo "Waiting for worker (thumbs + ready)…"
sleep 20

if [[ -n "${FIRST_PHOTO_ID}" ]]; then
  echo "Adding follower comment on first photo…"
  FOLLOWER_TOKEN="$(sign_in "${QA_FOLLOWER_EMAIL}")"
  curl -sS -o /dev/null -w "Comment HTTP %{http_code}\n" \
    -X POST "${API_BASE}/v1/babies/${BABY_ID}/photos/${FIRST_PHOTO_ID}/comments" \
    -H "Authorization: Bearer ${FOLLOWER_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d '{"body":"QA gallery comment"}'
fi

echo "Done. Pull to refresh Gallery on the emulator."
