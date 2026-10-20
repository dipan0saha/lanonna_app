#!/usr/bin/env bash
# Create or update Cloud Scheduler jobs that publish to the worker Pub/Sub topic.
# Idempotent create-or-update. Schedulers are managed here (not Terraform) so operators
# can adjust schedules without a Terraform apply.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=lib/env.sh
source "${ROOT}/scripts/lib/env.sh"

lanonna_resolve_environment
PROJECT_ID="${GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
TOPIC="${WORKER_PUBSUB_TOPIC:-lanonna-async-commands}"

upsert_pubsub_job() {
  local job_name="$1"
  local schedule="$2"
  local message_body="$3"
  local description="$4"

  if gcloud scheduler jobs describe "${job_name}" --project="${PROJECT_ID}" --location="${REGION}" >/dev/null 2>&1; then
    gcloud scheduler jobs update pubsub "${job_name}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --schedule="${schedule}" \
      --time-zone="UTC" \
      --topic="${TOPIC}" \
      --message-body="${message_body}" \
      --description="${description}"
  else
    gcloud scheduler jobs create pubsub "${job_name}" \
      --project="${PROJECT_ID}" \
      --location="${REGION}" \
      --schedule="${schedule}" \
      --time-zone="UTC" \
      --topic="${TOPIC}" \
      --message-body="${message_body}" \
      --description="${description}"
  fi
  echo "Scheduler job ${job_name} (${schedule} UTC) → ${PROJECT_ID} pubsub:${TOPIC}"
}

WEEKLY_JOB="${WEEKLY_DIGEST_JOB_NAME:-weekly-notification-digest}"
upsert_pubsub_job "${WEEKLY_JOB}" "0 14 * * 0" '{"type":"weekly_notification_digest"}' \
  "Weekly in-app notification digest push for digest=weekly users"

EXPIRE_JOB="${EXPIRE_INVITES_JOB_NAME:-expire-pending-invitations}"
upsert_pubsub_job "${EXPIRE_JOB}" "0 6 * * *" '{"type":"expire_pending_invitations"}' \
  "Mark pending invitations past expires_at as expired"
