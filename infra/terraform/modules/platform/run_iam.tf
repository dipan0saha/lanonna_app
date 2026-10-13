# GCS signed URLs from Cloud Run (no JSON key).
resource "google_service_account_iam_member" "api_self_token_creator" {
  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.api.email}"
}

# Pub/Sub → worker OIDC push: invoker + token creator in Terraform when push subs are enabled.
# scripts/apply-dev-run-iam.sh still strips allUsers and reconciles if apply lacked setIamPolicy.

resource "google_cloud_run_v2_service_iam_member" "worker_pubsub_invoker" {
  count = var.enable_worker_push_subscription ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.worker_cloud_run_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "worker_sa_invoker" {
  count = var.enable_worker_push_subscription ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.worker_cloud_run_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.worker.email}"
}

# Export media URLs are V4-signed by the worker identity (no JSON key).
resource "google_service_account_iam_member" "worker_self_token_creator" {
  service_account_id = google_service_account.worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_service_account_iam_member" "worker_pubsub_token_creator" {
  count = var.enable_worker_push_subscription ? 1 : 0

  service_account_id = google_service_account.worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
