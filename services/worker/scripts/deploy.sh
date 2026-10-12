#!/usr/bin/env bash
# Worker deploy. Sender checks run before Cloud Build (#43).
set -euo pipefail

# Assign KEY=VALUE lines into the environment without executing the file.
# Blank lines and #-comments are ignored. Values may be bare or wrapped in
# matching single or double quotes (so "La Nonna" is one value). An already
# set variable is left alone. Command substitutions in the file are not run.
load_unset_env_file() {
  local file="$1"
  local line key value
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    if [[ "${line}" != *=* ]]; then
      echo "Invalid env line in ${file}: ${line}" >&2
      return 1
    fi
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${line#*=}"
    if [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Invalid env name in ${file}: ${key}" >&2
      return 1
    fi
    if [[ "${value}" =~ ^\".*\"$ ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    if [[ -z "${!key+x}" ]]; then
      printf -v "${key}" '%s' "${value}"
      export "${key}"
    fi
  done < "${file}"
}

# Refuse a missing sender or hello@lanonna.app before any image build.
# Mailjet returns HTTP 200 for that address and then drops the message (#43).
require_mailjet_sender() {
  local env_file="$1"
  if [[ -z "${MAILJET_FROM_EMAIL:-}" ]]; then
    if [[ ! -f "${env_file}" ]]; then
      echo "MAILJET_FROM_EMAIL is required. Set it or add ${env_file}." >&2
      return 1
    fi
    load_unset_env_file "${env_file}"
  fi
  if [[ -z "${MAILJET_FROM_EMAIL:-}" ]]; then
    echo "MAILJET_FROM_EMAIL is required." >&2
    return 1
  fi
  local normalized
  normalized="$(printf '%s' "${MAILJET_FROM_EMAIL}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${normalized}" == "hello@lanonna.app" ]]; then
    echo "MAILJET_FROM_EMAIL=${MAILJET_FROM_EMAIL} is not a validated Mailjet sender." >&2
    return 1
  fi
}

deploy_worker() {
  local project_id="${GCP_PROJECT_ID:-lanonna-dev}"
  local region="${GCP_REGION:-us-central1}"
  local service="worker"
  local script_dir worker_dir repo_root image sql_instance conn worker_url

  script_dir="$(cd "$(dirname "$0")" && pwd)"
  worker_dir="$(cd "${script_dir}/.." && pwd)"
  repo_root="$(cd "${worker_dir}/../.." && pwd)"

  require_mailjet_sender "${repo_root}/infra/env/dev.worker.env"

  image="${region}-docker.pkg.dev/${project_id}/lanonna/${service}:$(git -C "${repo_root}" rev-parse --short HEAD 2>/dev/null || echo local)"

  gcloud config set project "${project_id}"

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
    --image="${image}" \
    --region="${region}" \
    --platform=managed \
    --service-account="lanonna-worker@${project_id}.iam.gserviceaccount.com" \
    --no-allow-unauthenticated \
    --add-cloudsql-instances="${conn}" \
    --set-secrets="DB_PASSWORD=db-lanonna-app-password:latest,MAILJET_API_KEY=mailjet-api-key:latest,MAILJET_API_SECRET=mailjet-api-secret:latest" \
    --set-env-vars="ENVIRONMENT=dev,GCP_PROJECT_ID=${project_id},CLOUD_SQL_CONNECTION_NAME=${conn},DB_USER=lanonna_app,DB_NAME=lanonna,DISPLAY_BUCKET=${project_id}-display,THUMBNAILS_BUCKET=${project_id}-thumbnails,INVITE_DEEP_LINK_BASE=lanonna://app,MAILJET_FROM_EMAIL=${MAILJET_FROM_EMAIL},MAILJET_FROM_NAME=${MAILJET_FROM_NAME:-La Nonna}" \
    --min-instances=0 \
    --max-instances=5 \
    --memory=512Mi \
    --cpu=1 \
    --timeout=300

  worker_url="$(gcloud run services describe "${service}" --region="${region}" --format='value(status.url)')"
  echo "Worker URL: ${worker_url}"
  echo "Deploy complete. Update Terraform worker_push_endpoint if this URL changed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  deploy_worker "$@"
fi
