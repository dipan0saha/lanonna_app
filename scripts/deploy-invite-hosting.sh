#!/usr/bin/env bash
# Deploy the HTTPS invite landing page to Firebase Hosting.
# Renders assetlinks.json from the app signing cert and, when APPLE_TEAM_ID
# is set, the iOS universal-link file. Does not print invitation tokens.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOSTING="${ROOT}/hosting"
# shellcheck source-path=SCRIPTDIR source=lib/env.sh
source "${ROOT}/scripts/lib/env.sh"
lanonna_resolve_environment
PROJECT_ID="${GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"

if [[ "${ENVIRONMENT}" == "prod" && -z "${ANDROID_SHA256:-}" ]]; then
  echo "ENVIRONMENT=prod requires ANDROID_SHA256 (release/upload keystore fingerprint). Debug keystore is not used on prod." >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase CLI is required (npm install -g firebase-tools)." >&2
  exit 1
fi
if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required." >&2
  exit 1
fi

python3 - "${ROOT}/scripts/render_invite_hosting.py" <<'PY'
import importlib.util
import os
import pathlib
import subprocess
import sys

script = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("render_invite_hosting", script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

root = script.parents[1]
public = root / "hosting" / "public"
well_known = public / ".well-known"
well_known.mkdir(parents=True, exist_ok=True)

raw = [part.strip() for part in os.environ.get("ANDROID_SHA256", "").split(",") if part.strip()]
if not raw:
    keystore = os.environ.get("ANDROID_KEYSTORE", "")
    alias = os.environ.get("ANDROID_KEY_ALIAS", "androiddebugkey")
    storepass = os.environ.get("ANDROID_KEYSTORE_PASS", "android")
    if not keystore:
        debug = pathlib.Path.home() / ".android" / "debug.keystore"
        if debug.is_file():
            keystore = str(debug)
    if keystore:
        result = subprocess.run(
            [
                "keytool", "-list", "-v",
                "-keystore", keystore,
                "-alias", alias,
                "-storepass", storepass,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        for line in result.stdout.splitlines():
            if "SHA256:" in line:
                raw.append(line.split("SHA256:", 1)[1].strip())
                break

if not raw:
    print(
        "No Android SHA-256 fingerprint. Set ANDROID_SHA256 (comma-separated) "
        "or ANDROID_KEYSTORE to the keystore that signs the app you ship. "
        "Debug builds on the owner machine usually use ~/.android/debug.keystore "
        "(alias androiddebugkey, storepass android).",
        file=sys.stderr,
    )
    sys.exit(1)

assetlinks = mod.render_assetlinks(raw)
(well_known / "assetlinks.json").write_text(mod.dumps(assetlinks), encoding="utf-8")
print(f"Wrote assetlinks.json for {mod.ANDROID_PACKAGE} ({len(assetlinks[0]['target']['sha256_cert_fingerprints'])} fingerprint(s)).")

team = os.environ.get("APPLE_TEAM_ID", "").strip()
aasa = mod.render_apple_app_site_association(team or None)
text = mod.dumps(aasa)
(well_known / "apple-app-site-association").write_text(text, encoding="utf-8")
(public / "apple-app-site-association").write_text(text, encoding="utf-8")
if team:
    print(f"Wrote apple-app-site-association for {team}.{mod.IOS_BUNDLE_ID}.")
else:
    print(
        "APPLE_TEAM_ID is unset. iOS universal links stay on the web fallback "
        "until you re-run with APPLE_TEAM_ID set to the 10-character Apple Team ID "
        "(Apple Developer → Membership). Android App Links do not need it.",
        file=sys.stderr,
    )
PY

echo "Enabling Firebase Hosting API on ${PROJECT_ID}..."
gcloud services enable firebasehosting.googleapis.com --project="${PROJECT_ID}"

echo "Deploying Hosting (invite landing page + /.well-known)..."
(
  cd "${HOSTING}"
  firebase deploy --only hosting --project "${PROJECT_ID}" --non-interactive
)

PN="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
MEMBER="serviceAccount:service-${PN}@gcp-sa-firebasehosting.iam.gserviceaccount.com"
echo "Granting Hosting permission to invoke the API (preview rewrite)..."
gcloud run services add-iam-policy-binding api \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --member="${MEMBER}" \
  --role="roles/run.invoker" \
  --quiet

echo "Invite hosting is live at https://${PROJECT_ID}.firebaseapp.com/invite"
echo "Worker invite links use INVITE_DEEP_LINK_BASE=https://${PROJECT_ID}.firebaseapp.com"
