#!/usr/bin/env bash
# Import existing lanonna-dev resources into Terraform state.
# Run from: infra/terraform/environments/dev (after terraform init).
set -euo pipefail

PROJECT="lanonna-dev"
REGION="us-central1"
ROOT="module.platform"

cd "$(dirname "$0")/../environments/dev"

import_api() {
  local api="$1"
  terraform import "${ROOT}.google_project_service.apis[\"${api}\"]" "${PROJECT}/${api}" || true
}

echo "Importing storage..."
terraform import "${ROOT}.google_storage_bucket.display" "${PROJECT}/lanonna-dev-display"
terraform import "${ROOT}.google_storage_bucket.thumbnails" "${PROJECT}/lanonna-dev-thumbnails"

echo "Importing Pub/Sub..."
terraform import "${ROOT}.google_pubsub_topic.upload" "projects/${PROJECT}/topics/photo-upload-finalized"
terraform import "${ROOT}.google_pubsub_subscription.worker" "projects/${PROJECT}/subscriptions/photo-upload-finalized-worker"

echo "Importing Artifact Registry..."
terraform import "${ROOT}.google_artifact_registry_repository.docker" "projects/${PROJECT}/locations/${REGION}/repositories/lanonna"

echo "Importing Cloud SQL..."
terraform import "${ROOT}.google_sql_database_instance.main" "projects/${PROJECT}/instances/lanonna-db"
terraform import "${ROOT}.google_sql_database.app" "${PROJECT}/lanonna-db/lanonna"
terraform import "${ROOT}.google_sql_user.app" "${PROJECT}/lanonna-db/lanonna_app"

echo "Importing service accounts..."
terraform import "${ROOT}.google_service_account.api" "projects/${PROJECT}/serviceAccounts/lanonna-api@${PROJECT}.iam.gserviceaccount.com"
terraform import "${ROOT}.google_service_account.worker" "projects/${PROJECT}/serviceAccounts/lanonna-worker@${PROJECT}.iam.gserviceaccount.com"
terraform import "${ROOT}.google_service_account.automation[0]" "projects/${PROJECT}/serviceAccounts/lanonna-automation@${PROJECT}.iam.gserviceaccount.com"

echo "Importing Secret Manager containers..."
for secret in database-url db-lanonna-app-password db-postgres-root-password mailjet-api-key mailjet-api-secret; do
  terraform import "${ROOT}.google_secret_manager_secret.app[\"${secret}\"]" "projects/${PROJECT}/secrets/${secret}"
done

echo "Importing GCS notification (if present)..."
terraform import "${ROOT}.google_storage_notification.display_upload" "lanonna-dev-display/notificationConfigs/1" || true

echo "Importing Firebase project..."
terraform import "${ROOT}.google_firebase_project.default[0]" "${PROJECT}" || true

echo "Importing enabled APIs (ignore errors if already in state)..."
APIS=(
  run.googleapis.com sqladmin.googleapis.com storage.googleapis.com pubsub.googleapis.com
  secretmanager.googleapis.com artifactregistry.googleapis.com cloudscheduler.googleapis.com
  iam.googleapis.com iamcredentials.googleapis.com cloudresourcemanager.googleapis.com
  servicenetworking.googleapis.com compute.googleapis.com eventarc.googleapis.com
  logging.googleapis.com monitoring.googleapis.com cloudbilling.googleapis.com firebase.googleapis.com
)
for api in "${APIS[@]}"; do
  import_api "$api"
done

echo "Import pass complete. Run: terraform plan"
