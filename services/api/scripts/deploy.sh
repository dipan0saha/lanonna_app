#!/usr/bin/env bash
# Build, push, and deploy the API to Cloud Run (lanonna-dev).
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="api"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/lanonna/${SERVICE}:$(git -C "$(dirname "$0")/../../.." rev-parse --short HEAD 2>/dev/null || echo local)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

gcloud config set project "${PROJECT_ID}"

# Prefer Cloud Build (no local Docker required). Set USE_LOCAL_DOCKER=1 to build locally.
if [[ "${USE_LOCAL_DOCKER:-0}" == "1" ]] && command -v docker >/dev/null; then
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  docker build --platform linux/amd64 -t "${IMAGE}" "${API_DIR}"
  docker push "${IMAGE}"
else
  gcloud builds submit "${API_DIR}" --tag "${IMAGE}" --project "${PROJECT_ID}" --quiet
fi

SQL_INSTANCE="${SQL_INSTANCE_NAME:-lanonna-db}"
CONN="${PROJECT_ID}:${REGION}:${SQL_INSTANCE}"

gcloud run deploy "${SERVICE}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --platform=managed \
  --service-account="lanonna-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  --allow-unauthenticated \
  --add-cloudsql-instances="${CONN}" \
  --set-secrets="DB_PASSWORD=db-lanonna-app-password:latest,ADMIN_API_KEY=admin-api-key:latest" \
  --set-env-vars="ENVIRONMENT=dev,GCP_PROJECT_ID=${PROJECT_ID},CLOUD_SQL_CONNECTION_NAME=${CONN},DB_USER=lanonna_app,DB_NAME=lanonna,GCS_SIGNING_SERVICE_ACCOUNT=lanonna-api@${PROJECT_ID}.iam.gserviceaccount.com,DISPLAY_BUCKET=${PROJECT_ID}-display,APP_CHECK_ENFORCE=true" \
  --min-instances=0 \
  --max-instances=10 \
  --memory=512Mi \
  --cpu=1

echo "Deployed. URL:"
gcloud run services describe "${SERVICE}" --region="${REGION}" --format='value(status.url)'
