#!/usr/bin/env bash
# Cloud Run IAM for Pub/Sub push (OIDC). Terraform may lack run.services.setIamPolicy on some principals.
set -euo pipefail

PROJECT="${GCP_PROJECT_ID:-lanonna-dev}"
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

echo "Worker Run IAM + Pub/Sub token creator applied."
