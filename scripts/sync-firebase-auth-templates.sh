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

patch_config() {
  local update_mask="$1"
  local payload="$2"
  local token
  token="$(gcloud auth print-access-token --project="${PROJECT_ID}")"
  local http_code
  http_code="$(curl -sS -o /tmp/firebase-auth-template-response.json -w '%{http_code}' \
    -X PATCH "https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config?updateMask=${update_mask}" \
    -H "Authorization: Bearer ${token}" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    -d "${payload}")"
  if [[ "$http_code" != "200" ]]; then
    echo "PATCH failed (HTTP ${http_code}) updateMask=${update_mask}:" >&2
    cat /tmp/firebase-auth-template-response.json >&2
    return 1
  fi
  return 0
}

fetch_verify_template_field() {
  local field="$1"
  local token
  token="$(gcloud auth print-access-token --project="${PROJECT_ID}")"
  python3 - <<PY
import json, urllib.request
token = """${token}"""
project = """${PROJECT_ID}"""
field = """${field}"""
req = urllib.request.Request(
    f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project}/config",
    headers={"Authorization": f"Bearer {token}", "X-Goog-User-Project": project},
)
with urllib.request.urlopen(req) as resp:
    cfg = json.load(resp)
t = cfg["notification"]["sendEmail"]["verifyEmailTemplate"]
val = t.get(field, "")
if field == "body":
    print("VERIFY_BODY_LEN", len(val))
    print("VERIFY_BODY_HAS_CTA", "Verify my email" in val)
else:
    print(val)
PY
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

if ! gcloud auth application-default print-access-token --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Hint: run bash scripts/configure-firebase-auth-email-project.sh first (ADC quota project)." >&2
fi

SUBJECT="$(tr -d '\r' <"$SUBJECT_FILE" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' )"
FAIL=0

echo "Applying sender display name..."
SENDER_PAYLOAD="$(python3 -c 'import json; print(json.dumps({"notification":{"sendEmail":{"verifyEmailTemplate":{"senderDisplayName":"La Nonna"}}}}))')"
patch_config "notification.sendEmail.verifyEmailTemplate.senderDisplayName" "$SENDER_PAYLOAD" || FAIL=1

echo "Applying HTML body (separate from subject — Firebase may ignore body on some projects)..."
BODY_PAYLOAD="$(python3 - <<PY
import json
body = open("${BODY_FILE}", encoding="utf-8").read()
print(json.dumps({"notification": {"sendEmail": {"verifyEmailTemplate": {"body": body, "bodyFormat": "HTML"}}}}))
PY
)"
if patch_config "notification.sendEmail.verifyEmailTemplate.body,notification.sendEmail.verifyEmailTemplate.bodyFormat" "$BODY_PAYLOAD"; then
  HAS_CTA="$(fetch_verify_template_field body | awk '/VERIFY_BODY_HAS_CTA/ {print $2}')"
  if [[ "$HAS_CTA" != "True" ]]; then
    echo "Warning: API accepted body PATCH but remote template still lacks branded CTA." >&2
    echo "Firebase may block body/subject updates (EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED)." >&2
    echo "Open Firebase Support and request manual apply of packages/firebase-auth-email-templates/verify_email.*" >&2
    FAIL=1
  else
    echo "Verified branded HTML body on ${PROJECT_ID}."
  fi
else
  FAIL=1
fi

echo "Applying subject..."
SUBJECT_PAYLOAD="$(python3 - <<PY
import json
subject = open("${SUBJECT_FILE}", encoding="utf-8").read().strip()
print(json.dumps({"notification": {"sendEmail": {"verifyEmailTemplate": {"subject": subject}}}}))
PY
)"
if ! patch_config "notification.sendEmail.verifyEmailTemplate.subject" "$SUBJECT_PAYLOAD"; then
  if grep -q EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED /tmp/firebase-auth-template-response.json 2>/dev/null; then
    echo "Subject blocked by Firebase (EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED)." >&2
    echo "Default subject still uses %APP_NAME% — set display name via configure-firebase-auth-email-project.sh." >&2
  fi
  FAIL=1
else
  echo "Applied subject on ${PROJECT_ID}."
fi

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "All verify email template fields applied on ${PROJECT_ID}."
