#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
REGION="${GCP_REGION:-us-central1}"
SERVICE="worker"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/lanonna/${SERVICE}:$(git -C "$(dirname "$0")/../../.." rev-parse --short HEAD 2>/dev/null || echo local)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${WORKER_DIR}/../.." && pwd)"

gcloud config set project "${PROJECT_ID}"

if [[ "${USE_LOCAL_DOCKER:-0}" == "1" ]] && command -v docker >/dev/null; then
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  docker build --platform linux/amd64 -t "${IMAGE}" -f "${WORKER_DIR}/Dockerfile" "${REPO_ROOT}"
  docker push "${IMAGE}"
else
  gcloud builds submit "${REPO_ROOT}" \
    --config="${WORKER_DIR}/cloudbuild.yaml" \
    --substitutions="_AR_IMAGE=${IMAGE}" \
    --project "${PROJECT_ID}" \
    --quiet
fi

SQL_INSTANCE="${SQL_INSTANCE_NAME:-lanonna-db}"
CONN="${PROJECT_ID}:${REGION}:${SQL_INSTANCE}"

# Sender is configuration, not a secret. Dev's validated address lives in
# infra/env/dev.worker.env. A missing value or hello@lanonna.app must not deploy:
# Mailjet returns HTTP 200 for that sender and then drops the message (#43).
WORKER_ENV_FILE="${REPO_ROOT}/infra/env/dev.worker.env"
if [[ -z "${MAILJET_FROM_EMAIL:-}" ]]; then
  if [[ ! -f "${WORKER_ENV_FILE}" ]]; then
    echo "MAILJET_FROM_EMAIL is required. Set it or add ${WORKER_ENV_FILE}." >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "${WORKER_ENV_FILE}"
  set +a
fi
if [[ -z "${MAILJET_FROM_EMAIL:-}" ]]; then
  echo "MAILJET_FROM_EMAIL is required." >&2
  exit 1
fi
FROM_EMAIL_NORMALIZED="$(printf '%s' "${MAILJET_FROM_EMAIL}" | tr '[:upper:]' '[:lower:]')"
if [[ "${FROM_EMAIL_NORMALIZED}" == "hello@lanonna.app" ]]; then
  echo "MAILJET_FROM_EMAIL=${MAILJET_FROM_EMAIL} is not a validated Mailjet sender." >&2
  exit 1
fi

gcloud run deploy "${SERVICE}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --platform=managed \
  --service-account="lanonna-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
  --no-allow-unauthenticated \
  --add-cloudsql-instances="${CONN}" \
  --set-secrets="DB_PASSWORD=db-lanonna-app-password:latest,MAILJET_API_KEY=mailjet-api-key:latest,MAILJET_API_SECRET=mailjet-api-secret:latest" \
  --set-env-vars="ENVIRONMENT=dev,GCP_PROJECT_ID=${PROJECT_ID},CLOUD_SQL_CONNECTION_NAME=${CONN},DB_USER=lanonna_app,DB_NAME=lanonna,DISPLAY_BUCKET=${PROJECT_ID}-display,THUMBNAILS_BUCKET=${PROJECT_ID}-thumbnails,INVITE_DEEP_LINK_BASE=lanonna://app,MAILJET_FROM_EMAIL=${MAILJET_FROM_EMAIL},MAILJET_FROM_NAME=${MAILJET_FROM_NAME:-La Nonna}" \
  --min-instances=0 \
  --max-instances=5 \
  --memory=512Mi \
  --cpu=1 \
  --timeout=300

WORKER_URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --format='value(status.url)')"
echo "Worker URL: ${WORKER_URL}"

echo "Deploy complete. Update Terraform worker_push_endpoint if this URL changed."
