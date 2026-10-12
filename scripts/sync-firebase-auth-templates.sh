#!/usr/bin/env bash
# Apply or verify Firebase Auth email templates (Identity Toolkit).
#
#   check         Local files only. No Google credentials. Safe for a laptop without gcloud.
#   check-remote  Live project must match La Nonna sender, subject, HTML, and public-facing name.
#   apply         Patch only fields that differ, then run the same remote check.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${ROOT}/scripts/firebase_auth_email_config.py"
PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
MODE="${1:-check}"

if [[ "$MODE" == "check" ]]; then
  python3 "$PY" local-check
  exit 0
fi

if [[ "$MODE" != "apply" && "$MODE" != "check-remote" ]]; then
  echo "Usage: $0 [check|check-remote|apply]" >&2
  exit 2
fi

python3 "$PY" local-check

if ! gcloud auth application-default print-access-token --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Hint: run bash scripts/configure-firebase-auth-email-project.sh apply first (ADC quota project)." >&2
fi

token() {
  gcloud auth print-access-token --project="${PROJECT_ID}"
}

fetch_config() {
  python3 - "${PROJECT_ID}" "$(token)" "$1" <<'PY'
import json, sys, urllib.request
project, token, dest = sys.argv[1], sys.argv[2], sys.argv[3]
req = urllib.request.Request(
    f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project}/config",
    headers={"Authorization": f"Bearer {token}", "X-Goog-User-Project": project},
)
with urllib.request.urlopen(req) as resp:
    open(dest, "w", encoding="utf-8").write(resp.read().decode("utf-8"))
PY
}

patch_config() {
  local update_mask="$1"
  local payload="$2"
  local http_code
  http_code="$(curl -sS -o /tmp/firebase-auth-template-response.json -w '%{http_code}' \
    -X PATCH "https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config?updateMask=${update_mask}" \
    -H "Authorization: Bearer $(token)" \
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

write_snapshot() {
  local config_file="$1"
  local dest="$2"
  local gcp_name firebase_name brand
  gcp_name="$(gcloud projects describe "${PROJECT_ID}" --format='value(name)')"
  firebase_name="$(python3 - "${PROJECT_ID}" "$(token)" <<'PY'
import json, sys, urllib.request
project, token = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    f"https://firebase.googleapis.com/v1beta1/projects/{project}",
    headers={"Authorization": f"Bearer {token}", "X-Goog-User-Project": project},
)
with urllib.request.urlopen(req) as resp:
    print(json.load(resp).get("displayName", ""))
PY
)"
  local project_number
  project_number="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
  brand="$(python3 - "${PROJECT_ID}" "${project_number}" "$(token)" <<'PY'
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
        print("")
        raise SystemExit(0)
    raise
brands = payload.get("brands") or []
print(brands[0].get("applicationTitle", "") if brands else "")
PY
)"
  BRAND_TITLE="$brand" GCP_NAME="$gcp_name" FIREBASE_NAME="$firebase_name" \
    CONFIG_FILE="$config_file" DEST="$dest" python3 - <<'PY'
import json, os
from pathlib import Path
config = json.loads(Path(os.environ["CONFIG_FILE"]).read_text(encoding="utf-8"))
brand = os.environ["BRAND_TITLE"] or None
Path(os.environ["DEST"]).write_text(json.dumps({
    "config": config,
    "brand_title": brand,
    "gcp_project_name": os.environ["GCP_NAME"],
    "firebase_display_name": os.environ["FIREBASE_NAME"],
}), encoding="utf-8")
PY
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
fetch_config "${WORKDIR}/config.json"

if [[ "$MODE" == "apply" ]]; then
  count="$(python3 "$PY" plan-patches "${WORKDIR}/config.json" "${WORKDIR}/patches.json")"
  if [[ "$count" == "0" ]]; then
    echo "Templates already match the repo. Nothing to patch."
  else
    echo "Applying ${count} template field(s)..."
    python3 - "${WORKDIR}" <<'PY'
import json, pathlib, sys
workdir = pathlib.Path(sys.argv[1])
patches = json.loads((workdir / "patches.json").read_text(encoding="utf-8"))
for index, patch in enumerate(patches):
    (workdir / f"patch-{index}.json").write_text(json.dumps(patch), encoding="utf-8")
PY
    fail=0
    for patch_file in "${WORKDIR}"/patch-*.json; do
      update_mask="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["update_mask"])' "$patch_file")"
      payload="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["body"]))' "$patch_file")"
      echo "PATCH ${update_mask}"
      if ! patch_config "$update_mask" "$payload"; then
        if python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from firebase_auth_email_config import patch_blocked; from pathlib import Path; raise SystemExit(0 if patch_blocked(Path("/tmp/firebase-auth-template-response.json").read_text()) else 1)' "${ROOT}/scripts"; then
          echo "Firebase blocked this field (EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED)." >&2
          echo "See scripts/firebase-auth-template-support-request.md." >&2
        fi
        fail=1
      fi
    done
    if [[ "$fail" -ne 0 ]]; then
      echo "One or more template fields were not applied." >&2
      exit 1
    fi
    fetch_config "${WORKDIR}/config.json"
  fi
fi

write_snapshot "${WORKDIR}/config.json" "${WORKDIR}/snapshot.json"
python3 "$PY" evaluate "${WORKDIR}/snapshot.json"
