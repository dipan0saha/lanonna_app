#!/usr/bin/env bash
# Set the names Firebase Auth uses, then you can prove it with check.
#
# %APP_NAME% is the OAuth brand application title (Firebase "Public-facing name"),
# not the GCP project name. This script sets all three and is safe to re-run.
#
#   bash scripts/configure-firebase-auth-email-project.sh apply
#   bash scripts/configure-firebase-auth-email-project.sh check
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${ROOT}/scripts/firebase_auth_email_config.py"
PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
DISPLAY_NAME="${FIREBASE_DISPLAY_NAME:-La Nonna}"
MODE="${1:-apply}"

if [[ "$MODE" != "apply" && "$MODE" != "check" ]]; then
  echo "Usage: $0 [apply|check]" >&2
  exit 2
fi

token() {
  gcloud auth print-access-token --project="${PROJECT_ID}"
}

gcp_project_name() {
  gcloud projects describe "${PROJECT_ID}" --format='value(name)'
}

firebase_display_name() {
  python3 - "${PROJECT_ID}" "$(token)" <<'PY'
import json, sys, urllib.request
project, token = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    f"https://firebase.googleapis.com/v1beta1/projects/{project}",
    headers={"Authorization": f"Bearer {token}", "X-Goog-User-Project": project},
)
with urllib.request.urlopen(req) as resp:
    print(json.load(resp).get("displayName", ""))
PY
}

# Prints the brand applicationTitle, or the literal MISSING when no brand exists.
brand_title() {
  local project_number
  project_number="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
  python3 - "${PROJECT_ID}" "${project_number}" "$(token)" <<'PY'
import json, sys, urllib.error, urllib.request
project, number, token = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"https://clientauthconfig.googleapis.com/v1/projects/{number}/brands"
req = urllib.request.Request(
    url,
    headers={"Authorization": f"Bearer {token}", "X-Goog-User-Project": project},
)
try:
    with urllib.request.urlopen(req) as resp:
        payload = json.load(resp)
except urllib.error.HTTPError as exc:
    if exc.code == 404:
        print("MISSING")
        raise SystemExit(0)
    detail = exc.read().decode("utf-8", errors="replace")
    print(detail, file=sys.stderr)
    raise SystemExit(1)
brands = payload.get("brands") or []
if not brands:
    print("MISSING")
else:
    print(brands[0].get("applicationTitle") or "")
PY
}

report_names() {
  echo "GCP project name: $(gcp_project_name)"
  echo "Firebase display name: $(firebase_display_name)"
  local title
  title="$(brand_title)"
  if [[ "$title" == "MISSING" ]]; then
    echo "Public-facing name (%APP_NAME%): (not set)"
  else
    echo "Public-facing name (%APP_NAME%): ${title}"
  fi
}

if [[ "$MODE" == "check" ]]; then
  report_names
  title="$(brand_title)"
  fail=0
  [[ "$(gcp_project_name)" == "$DISPLAY_NAME" ]] || fail=1
  [[ "$(firebase_display_name)" == "$DISPLAY_NAME" ]] || fail=1
  action="$(python3 "$PY" brand-action "${title}")"
  [[ "$action" == "ok" ]] || fail=1
  if [[ "$fail" -ne 0 ]]; then
    echo "Names do not match ${DISPLAY_NAME}. Run: bash scripts/configure-firebase-auth-email-project.sh apply" >&2
    if [[ "$action" == "console" ]]; then
      echo "No OAuth brand exists, so %APP_NAME% is still the default project-<number>." >&2
      echo "Enable Google sign-in once and set the public-facing name to ${DISPLAY_NAME}:" >&2
      echo "  https://console.firebase.google.com/project/${PROJECT_ID}/authentication/providers" >&2
      echo "Then set Project settings → General → Public-facing name, and re-run check." >&2
    fi
    exit 1
  fi
  echo "Project names and public-facing name match ${DISPLAY_NAME}."
  exit 0
fi

echo "Setting Application Default Credentials quota project to ${PROJECT_ID}..."
gcloud auth application-default set-quota-project "${PROJECT_ID}"

current_gcp="$(gcp_project_name)"
if [[ "$current_gcp" == "$DISPLAY_NAME" ]]; then
  echo "GCP project name already ${DISPLAY_NAME}."
else
  echo "Setting GCP project name to ${DISPLAY_NAME}..."
  gcloud projects update "${PROJECT_ID}" --name="${DISPLAY_NAME}"
fi

current_firebase="$(firebase_display_name)"
if [[ "$current_firebase" == "$DISPLAY_NAME" ]]; then
  echo "Firebase display name already ${DISPLAY_NAME}."
else
  echo "Setting Firebase display name to ${DISPLAY_NAME}..."
  curl -sS -f -X PATCH \
    "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}?updateMask=displayName" \
    -H "Authorization: Bearer $(token)" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    -d "{\"displayName\":\"${DISPLAY_NAME}\"}" >/dev/null
fi

title="$(brand_title)"
action="$(python3 "$PY" brand-action "${title}")"
if [[ "$action" == "ok" ]]; then
  echo "Public-facing name already ${DISPLAY_NAME}."
elif [[ "$action" == "patch" ]]; then
  project_number="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
  echo "Setting public-facing name (%APP_NAME%) to ${DISPLAY_NAME}..."
  http_code="$(curl -sS -o /tmp/lanonna-brand-patch.json -w '%{http_code}' -X PATCH \
    "https://clientauthconfig.googleapis.com/v1/projects/${project_number}/brands/${project_number}?updateMask=applicationTitle" \
    -H "Authorization: Bearer $(token)" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    -d "{\"applicationTitle\":\"${DISPLAY_NAME}\"}")"
  if [[ "$http_code" != "200" ]]; then
    echo "Could not update the public-facing name (HTTP ${http_code})." >&2
    cat /tmp/lanonna-brand-patch.json >&2 || true
    echo "Set it in the console, then re-run check:" >&2
    echo "  https://console.firebase.google.com/project/${PROJECT_ID}/settings/general" >&2
    echo "  Public-facing name → ${DISPLAY_NAME}" >&2
    exit 1
  fi
else
  echo "No OAuth brand exists, so %APP_NAME% cannot be set from this script." >&2
  echo "Creating a brand with the IAP API would mark it internal-only and can break Google sign-in." >&2
  echo "Do this once in the Firebase console, then re-run this script:" >&2
  echo "  1. https://console.firebase.google.com/project/${PROJECT_ID}/authentication/providers" >&2
  echo "     Google → Enable → Public-facing name ${DISPLAY_NAME} → support email you control → Save" >&2
  echo "  2. https://console.firebase.google.com/project/${PROJECT_ID}/settings/general" >&2
  echo "     Confirm Public-facing name is ${DISPLAY_NAME}." >&2
  echo "GCP project name and Firebase display name were still updated." >&2
  exit 1
fi

echo "Done. Run: bash scripts/sync-firebase-auth-templates.sh apply"
echo "Then:     bash scripts/sync-firebase-auth-templates.sh check-remote"
