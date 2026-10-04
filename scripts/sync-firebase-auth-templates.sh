#!/usr/bin/env bash
# Apply or validate Firebase Auth email templates (Identity Platform API).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/packages/firebase-auth-email-templates"
PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
MODE="${1:-check}"

SUBJECT_FILE="${SRC}/verify_email.subject"
BODY_FILE="${SRC}/verify_email.html"

require_files() {
  if [[ ! -f "$SUBJECT_FILE" || ! -f "$BODY_FILE" ]]; then
    echo "Missing verify_email templates under $SRC" >&2
    exit 1
  fi
  if ! grep -q '%LINK%' "$BODY_FILE"; then
    echo "verify_email.html must contain %LINK%" >&2
    exit 1
  fi
  if ! grep -qi 'La Nonna' "$BODY_FILE" "$SUBJECT_FILE"; then
    echo "Templates must mention La Nonna" >&2
    exit 1
  fi
}

if [[ "$MODE" == "check" ]]; then
  require_files
  echo "Firebase auth email templates OK."
  exit 0
fi

if [[ "$MODE" != "apply" ]]; then
  echo "Usage: $0 [check|apply]" >&2
  exit 1
fi

require_files

SUBJECT="$(tr -d '\r' <"$SUBJECT_FILE" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' )"
BODY="$(tr -d '\r' <"$BODY_FILE")"

TOKEN="$(gcloud auth print-access-token --project="${PROJECT_ID}")"
UPDATE_MASK="notification.sendEmail.verifyEmailTemplate.subject,notification.sendEmail.verifyEmailTemplate.body,notification.sendEmail.verifyEmailTemplate.bodyFormat,notification.sendEmail.verifyEmailTemplate.senderDisplayName"

# Escape for JSON (python is available on dev machines)
PAYLOAD="$(python3 - <<PY
import json
subject = open("${SUBJECT_FILE}", encoding="utf-8").read().strip()
body = open("${BODY_FILE}", encoding="utf-8").read()
print(json.dumps({
  "notification": {
    "sendEmail": {
      "verifyEmailTemplate": {
        "subject": subject,
        "body": body,
        "bodyFormat": "HTML",
        "senderDisplayName": "La Nonna",
      }
    }
  }
}))
PY
)"

URL="https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config?updateMask=${UPDATE_MASK}"

HTTP_CODE="$(curl -sS -o /tmp/firebase-auth-template-response.json -w '%{http_code}' \
  -X PATCH "$URL" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "PATCH failed (HTTP ${HTTP_CODE}):" >&2
  cat /tmp/firebase-auth-template-response.json >&2
  if grep -q EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED /tmp/firebase-auth-template-response.json 2>/dev/null; then
    echo "Hint: apply templates manually in Firebase Console → Authentication → Templates." >&2
    echo "See packages/firebase-auth-email-templates/README.md" >&2
  fi
  exit 1
fi

echo "Applied verify email template to ${PROJECT_ID}."
