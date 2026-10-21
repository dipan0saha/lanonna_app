#!/usr/bin/env bash
# Worker deploy. Sender checks run before Cloud Build (#43).
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/lib" && pwd)"
# shellcheck source-path=SCRIPTDIR source=../../../scripts/lib/env_file.sh
source "${LIB_DIR}/env_file.sh"
# shellcheck source-path=SCRIPTDIR source=../../../scripts/lib/env.sh
source "${LIB_DIR}/env.sh"

# Refuse a missing sender or hello@lanonna.app before any image build.
# Mailjet returns HTTP 200 for that address and then drops the message (#43).
# Precedence: exported shell value > gitignored local file > tracked env file.
require_mailjet_sender() {
  local env_file="$1"
  local local_env_file="$2"
  if [[ -f "${local_env_file}" ]]; then
    load_unset_env_file "${local_env_file}"
  fi
  if [[ -f "${env_file}" ]]; then
    load_unset_env_file "${env_file}"
  fi
  if [[ -z "${MAILJET_FROM_EMAIL:-}" ]]; then
    echo "MAILJET_FROM_EMAIL is required. Export it or set it in ${local_env_file} (copy from ${local_env_file}.example)." >&2
    return 1
  fi
  lanonna_reject_placeholder MAILJET_FROM_EMAIL "${MAILJET_FROM_EMAIL}" || return 1
  local normalized
  normalized="$(printf '%s' "${MAILJET_FROM_EMAIL}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${normalized}" == "hello@lanonna.app" ]]; then
    echo "MAILJET_FROM_EMAIL=${MAILJET_FROM_EMAIL} is not a validated Mailjet sender." >&2
    return 1
  fi
}

deploy_worker() {
  local region="${GCP_REGION:-us-central1}"
  local service="worker"
  local script_dir worker_dir repo_root image sql_instance conn worker_url project_id worker_env_file
  local worker_local_env_file

  script_dir="$(cd "$(dirname "$0")" && pwd)"
  worker_dir="$(cd "${script_dir}/.." && pwd)"
  repo_root="$(cd "${worker_dir}/../.." && pwd)"

  lanonna_resolve_environment
  project_id="${GCP_PROJECT_ID}"
  worker_env_file="${WORKER_ENV_FILE:-$(lanonna_infra_env_file worker)}"
  worker_local_env_file="${WORKER_LOCAL_ENV_FILE:-$(lanonna_infra_env_local_file worker)}"

  require_mailjet_sender "${worker_env_file}" "${worker_local_env_file}"

  image="${region}-docker.pkg.dev/${project_id}/lanonna/${service}:$(git -C "${repo_root}" rev-parse --short HEAD 2>/dev/null || echo local)"

  if [[ "${USE_LOCAL_DOCKER:-0}" == "1" ]] && command -v docker >/dev/null; then
    gcloud auth configure-docker "${region}-docker.pkg.dev" --quiet
    docker build --platform linux/amd64 -t "${image}" -f "${worker_dir}/Dockerfile" "${repo_root}"
    docker push "${image}"
  else
    gcloud builds submit "${repo_root}" \
      --config="${worker_dir}/cloudbuild.yaml" \
      --substitutions="_AR_IMAGE=${image}" \
      --project "${project_id}" \
      --quiet
  fi

  sql_instance="${SQL_INSTANCE_NAME:-lanonna-db}"
  conn="${project_id}:${region}:${sql_instance}"

  gcloud run deploy "${service}" \
    --project="${project_id}" \
    --image="${image}" \
    --region="${region}" \
    --platform=managed \
    --service-account="lanonna-worker@${project_id}.iam.gserviceaccount.com" \
    --no-allow-unauthenticated \
    --add-cloudsql-instances="${conn}" \
    --set-secrets="DB_PASSWORD=db-lanonna-app-password:latest,MAILJET_API_KEY=mailjet-api-key:latest,MAILJET_API_SECRET=mailjet-api-secret:latest" \
    --set-env-vars="ENVIRONMENT=${ENVIRONMENT},GCP_PROJECT_ID=${project_id},CLOUD_SQL_CONNECTION_NAME=${conn},DB_USER=lanonna_app,DB_NAME=lanonna,DISPLAY_BUCKET=${project_id}-display,THUMBNAILS_BUCKET=${project_id}-thumbnails,INVITE_DEEP_LINK_BASE=https://${project_id}.firebaseapp.com,GCS_SIGNING_SERVICE_ACCOUNT=lanonna-worker@${project_id}.iam.gserviceaccount.com,MAILJET_FROM_EMAIL=${MAILJET_FROM_EMAIL},MAILJET_FROM_NAME=${MAILJET_FROM_NAME:-La Nonna}" \
    --min-instances=0 \
    --max-instances=5 \
    --memory=512Mi \
    --cpu=1 \
    --timeout=300

  worker_url="$(gcloud run services describe "${service}" --project="${project_id}" --region="${region}" --format='value(status.url)')"
  echo "Worker URL: ${worker_url}"
  echo "Deploy complete. Update Terraform worker_push_endpoint if this URL changed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  deploy_worker "$@"
fi
