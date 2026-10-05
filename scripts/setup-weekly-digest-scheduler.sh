#!/usr/bin/env bash
# Create or update Cloud Scheduler job for weekly notification digest (dev).
# Publishes to the worker Pub/Sub topic (same path as API notify payloads).
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
REGION="${GCP_REGION:-us-central1}"
JOB_NAME="${WEEKLY_DIGEST_JOB_NAME:-weekly-notification-digest}"
TOPIC="${WORKER_PUBSUB_TOPIC:-lanonna-async-commands}"
MESSAGE_BODY='{"type":"weekly_notification_digest"}'

gcloud config set project "${PROJECT_ID}"

if gcloud scheduler jobs describe "${JOB_NAME}" --location="${REGION}" >/dev/null 2>&1; then
  gcloud scheduler jobs update pubsub "${JOB_NAME}" \
    --location="${REGION}" \
    --schedule="0 14 * * 0" \
    --time-zone="UTC" \
    --topic="${TOPIC}" \
    --message-body="${MESSAGE_BODY}" \
    --description="Weekly in-app notification digest push for digest=weekly users"
else
  gcloud scheduler jobs create pubsub "${JOB_NAME}" \
    --location="${REGION}" \
    --schedule="0 14 * * 0" \
    --time-zone="UTC" \
    --topic="${TOPIC}" \
    --message-body="${MESSAGE_BODY}" \
    --description="Weekly in-app notification digest push for digest=weekly users"
fi

echo "Scheduler job ${JOB_NAME} → pubsub:${TOPIC} (Sundays 14:00 UTC)"
