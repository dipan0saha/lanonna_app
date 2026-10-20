#!/usr/bin/env bash
# Worker Run IAM: strips public invoker and reconciles bindings Terraform also manages (run_iam.tf).
# Run after worker deploy if push fails or allUsers was re-added.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=lib/env.sh
source "${ROOT}/scripts/lib/env.sh"

lanonna_resolve_environment
PROJECT="${GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
PN="$(gcloud projects describe "${PROJECT}" --format='value(projectNumber)')"

gcloud run services add-iam-policy-binding worker \
  --project="${PROJECT}" \
  --region="${REGION}" \
  --member="serviceAccount:service-${PN}@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --quiet

gcloud run services add-iam-policy-binding worker \
  --project="${PROJECT}" \
  --region="${REGION}" \
  --member="serviceAccount:lanonna-worker@${PROJECT}.iam.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --quiet

gcloud run services remove-iam-policy-binding worker \
  --project="${PROJECT}" \
  --region="${REGION}" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --quiet 2>/dev/null || true

gcloud iam service-accounts add-iam-policy-binding "lanonna-worker@${PROJECT}.iam.gserviceaccount.com" \
  --project="${PROJECT}" \
  --member="serviceAccount:service-${PN}@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --quiet

# Worker signs 7-day export media URLs with its own identity (no JSON key).
gcloud iam service-accounts add-iam-policy-binding "lanonna-worker@${PROJECT}.iam.gserviceaccount.com" \
  --project="${PROJECT}" \
  --member="serviceAccount:lanonna-worker@${PROJECT}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --quiet

echo "Worker Run IAM + Pub/Sub and self token creator applied for ${PROJECT}."
