#!/usr/bin/env bash
# Cloud Scheduler → Pub/Sub: expire pending invitations (daily).
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
REGION="${GCP_REGION:-us-central1}"
JOB_NAME="${EXPIRE_INVITES_JOB_NAME:-expire-pending-invitations}"
TOPIC="${WORKER_PUBSUB_TOPIC:-lanonna-async-commands}"
MESSAGE_BODY='{"type":"expire_pending_invitations"}'

gcloud config set project "${PROJECT_ID}"

if gcloud scheduler jobs describe "${JOB_NAME}" --location="${REGION}" >/dev/null 2>&1; then
  gcloud scheduler jobs update pubsub "${JOB_NAME}" \
    --location="${REGION}" \
    --schedule="0 6 * * *" \
    --time-zone="UTC" \
    --topic="${TOPIC}" \
    --message-body="${MESSAGE_BODY}" \
    --description="Mark pending invitations past expires_at as expired"
else
  gcloud scheduler jobs create pubsub "${JOB_NAME}" \
    --location="${REGION}" \
    --schedule="0 6 * * *" \
    --time-zone="UTC" \
    --topic="${TOPIC}" \
    --message-body="${MESSAGE_BODY}" \
    --description="Mark pending invitations past expires_at as expired"
fi

echo "Scheduler job ${JOB_NAME} → pubsub:${TOPIC} (daily 06:00 UTC)"
