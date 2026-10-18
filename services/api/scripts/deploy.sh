#!/usr/bin/env bash
# Build, push, and deploy the API to Cloud Run (lanonna-dev).
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="api"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/lanonna/${SERVICE}:$(git -C "$(dirname "$0")/../../.." rev-parse --short HEAD 2>/dev/null || echo local)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${API_DIR}/../.." && pwd)"

# shellcheck source=../../../scripts/lib/env_file.sh
source "${REPO_ROOT}/scripts/lib/env_file.sh"

# Per-environment, non-secret Cloud Run settings (parsed, not executed). Variables
# already set in the shell win. Without the file the defaults below apply
# (scale to zero), so an environment opts in to warm instances explicitly.
API_ENV_FILE="${API_ENV_FILE:-${REPO_ROOT}/infra/env/dev.api.env}"
if [[ -f "${API_ENV_FILE}" ]]; then
  load_unset_env_file "${API_ENV_FILE}"
fi
API_MIN_INSTANCES="${API_MIN_INSTANCES:-0}"
API_MAX_INSTANCES="${API_MAX_INSTANCES:-10}"
if [[ ! "${API_MIN_INSTANCES}" =~ ^[0-9]+$ || ! "${API_MAX_INSTANCES}" =~ ^[0-9]+$ ]] \
  || (( API_MIN_INSTANCES > API_MAX_INSTANCES )); then
  echo "API_MIN_INSTANCES (${API_MIN_INSTANCES}) and API_MAX_INSTANCES (${API_MAX_INSTANCES}) must be integers with min <= max." >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

# Prefer Cloud Build (no local Docker required). Set USE_LOCAL_DOCKER=1 to build locally.
if [[ "${USE_LOCAL_DOCKER:-0}" == "1" ]] && command -v docker >/dev/null; then
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  docker build --platform linux/amd64 -t "${IMAGE}" -f "${API_DIR}/Dockerfile" "${REPO_ROOT}"
  docker push "${IMAGE}"
else
  gcloud builds submit "${REPO_ROOT}" \
    --config="${API_DIR}/cloudbuild.yaml" \
    --substitutions="_AR_IMAGE=${IMAGE}" \
    --project "${PROJECT_ID}" \
    --quiet
fi

SQL_INSTANCE="${SQL_INSTANCE_NAME:-lanonna-db}"
CONN="${PROJECT_ID}:${REGION}:${SQL_INSTANCE}"

# TEMP (2026-10): default false so sideloaded release APKs work without Play Integrity /
# per-device App Check debug tokens. Set APP_CHECK_ENFORCE=true (or edit default) before wide beta.
APP_CHECK_ENFORCE="${APP_CHECK_ENFORCE:-false}"

gcloud run deploy "${SERVICE}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --platform=managed \
  --service-account="lanonna-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  --allow-unauthenticated \
  --add-cloudsql-instances="${CONN}" \
  --set-secrets="DB_PASSWORD=db-lanonna-app-password:latest,ADMIN_API_KEY=admin-api-key:latest" \
  --set-env-vars="ENVIRONMENT=dev,GCP_PROJECT_ID=${PROJECT_ID},CLOUD_SQL_CONNECTION_NAME=${CONN},DB_USER=lanonna_app,DB_NAME=lanonna,GCS_SIGNING_SERVICE_ACCOUNT=lanonna-api@${PROJECT_ID}.iam.gserviceaccount.com,DISPLAY_BUCKET=${PROJECT_ID}-display,THUMBNAILS_BUCKET=${PROJECT_ID}-thumbnails,PUBSUB_TOPIC_COMMANDS=lanonna-async-commands,APP_CHECK_ENFORCE=${APP_CHECK_ENFORCE}" \
  --min-instances="${API_MIN_INSTANCES}" \
  --max-instances="${API_MAX_INSTANCES}" \
  --memory=512Mi \
  --cpu=1

echo "Deployed. URL:"
gcloud run services describe "${SERVICE}" --region="${REGION}" --format='value(status.url)'
