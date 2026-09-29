output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "bucket_display" {
  value = google_storage_bucket.display.name
}

output "bucket_thumbnails" {
  value = google_storage_bucket.thumbnails.name
}

output "pubsub_topic" {
  value = google_pubsub_topic.upload.name
}

output "pubsub_subscription_worker" {
  value = google_pubsub_subscription.worker.name
}

output "pubsub_subscription_worker_push" {
  value = var.enable_worker_push_subscription ? google_pubsub_subscription.worker_push[0].name : null
}

output "sql_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "sql_public_ip" {
  value = google_sql_database_instance.main.public_ip_address
}

output "artifact_registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "service_account_api_email" {
  value = google_service_account.api.email
}

output "service_account_worker_email" {
  value = google_service_account.worker.email
}

output "service_account_automation_email" {
  value = var.create_automation_sa ? google_service_account.automation[0].email : null
}
