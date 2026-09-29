#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="worker"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/lanonna/${SERVICE}:$(git -C "$(dirname "$0")/../../.." rev-parse --short HEAD 2>/dev/null || echo local)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

gcloud config set project "${PROJECT_ID}"

if [[ "${USE_LOCAL_DOCKER:-0}" == "1" ]] && command -v docker >/dev/null; then
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  docker build --platform linux/amd64 -t "${IMAGE}" "${WORKER_DIR}"
  docker push "${IMAGE}"
else
  gcloud builds submit "${WORKER_DIR}" --tag "${IMAGE}" --project "${PROJECT_ID}" --quiet
fi

gcloud run deploy "${SERVICE}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --platform=managed \
  --service-account="lanonna-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
  --no-allow-unauthenticated \
  --set-env-vars="ENVIRONMENT=dev,GCP_PROJECT_ID=${PROJECT_ID}" \
  --min-instances=0 \
  --max-instances=5 \
  --memory=512Mi \
  --cpu=1

WORKER_URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --format='value(status.url)')"
echo "Worker URL: ${WORKER_URL}"

# Pub/Sub push + Run invoker IAM: managed in Terraform (see infra/terraform).
if [[ "${CONFIGURE_PUBSUB_IN_DEPLOY:-0}" == "1" ]]; then
  echo "CONFIGURE_PUBSUB_IN_DEPLOY=1 is deprecated; use Terraform worker_push subscription."
fi

echo "Deploy complete. Update Terraform worker_push_endpoint if this URL changed."
