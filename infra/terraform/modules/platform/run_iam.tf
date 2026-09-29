# GCS signed URLs from Cloud Run (no JSON key).
resource "google_service_account_iam_member" "api_self_token_creator" {
  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.api.email}"
}

# Pub/Sub → worker OIDC: token creator is in Terraform; Run invoker bindings use
# scripts/apply-dev-run-iam.sh (some principals get 403 on run.services.setIamPolicy via TF).

resource "google_service_account_iam_member" "worker_pubsub_token_creator" {
  count = var.enable_worker_push_subscription ? 1 : 0

  service_account_id = google_service_account.worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
