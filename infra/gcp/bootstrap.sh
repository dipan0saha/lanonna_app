#!/usr/bin/env bash
# DEPRECATED: Use infra/terraform/environments/dev instead.
# Idempotent Path B GCP bootstrap for La Nonna (dev).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/project.env"

: "${GCP_PROJECT_ID:?}"
: "${GCP_REGION:=us-central1}"
: "${GCP_BILLING_ACCOUNT_ID:?}"

gcloud config set project "$GCP_PROJECT_ID"

if ! gcloud projects describe "$GCP_PROJECT_ID" &>/dev/null; then
  gcloud projects create "$GCP_PROJECT_ID" --name="La Nonna Dev"
  gcloud billing projects link "$GCP_PROJECT_ID" --billing-account="$GCP_BILLING_ACCOUNT_ID"
fi

APIS=(
  run.googleapis.com sqladmin.googleapis.com storage.googleapis.com pubsub.googleapis.com
  secretmanager.googleapis.com artifactregistry.googleapis.com cloudscheduler.googleapis.com
  iam.googleapis.com iamcredentials.googleapis.com cloudresourcemanager.googleapis.com
  servicenetworking.googleapis.com compute.googleapis.com eventarc.googleapis.com
  logging.googleapis.com monitoring.googleapis.com cloudbilling.googleapis.com
)
gcloud services enable "${APIS[@]}" --project="$GCP_PROJECT_ID"

PROJECT_NUMBER="$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')"

for sa in lanonna-automation lanonna-api lanonna-worker; do
  gcloud iam service-accounts create "$sa" --display-name="La Nonna ${sa#lanonna-}" 2>/dev/null || true
done

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:lanonna-automation@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor" --quiet >/dev/null || true

gcloud storage buckets create "gs://${GCS_BUCKET_DISPLAY}" --location="$GCP_REGION" --uniform-bucket-level-access 2>/dev/null || true
gcloud storage buckets create "gs://${GCS_BUCKET_THUMBNAILS}" --location="$GCP_REGION" --uniform-bucket-level-access 2>/dev/null || true

gcloud pubsub topics create "$PUBSUB_TOPIC_UPLOAD" --project="$GCP_PROJECT_ID" 2>/dev/null || true
gcloud pubsub subscriptions create "$PUBSUB_SUBSCRIPTION_WORKER" \
  --topic="$PUBSUB_TOPIC_UPLOAD" --project="$GCP_PROJECT_ID" --ack-deadline=120 2>/dev/null || true

gcloud pubsub topics add-iam-policy-binding "$PUBSUB_TOPIC_UPLOAD" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gs-project-accounts.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher" --project="$GCP_PROJECT_ID" --quiet 2>/dev/null || true

if ! gcloud storage buckets notifications list "gs://${GCS_BUCKET_DISPLAY}" --format='value(id)' | grep -q .; then
  gcloud storage buckets notifications create "gs://${GCS_BUCKET_DISPLAY}" \
    --topic="projects/${GCP_PROJECT_ID}/topics/${PUBSUB_TOPIC_UPLOAD}" \
    --event-types=OBJECT_FINALIZE --payload-format=json
fi

gcloud artifacts repositories create "$ARTIFACT_REPO" \
  --repository-format=docker --location="$ARTIFACT_LOCATION" \
  --project="$GCP_PROJECT_ID" 2>/dev/null || true

echo "Bootstrap complete for ${GCP_PROJECT_ID}. See SETUP.md for Firebase Blaze and secrets."
