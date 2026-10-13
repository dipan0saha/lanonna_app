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

output "pubsub_topic_commands" {
  value = google_pubsub_topic.async_commands.name
}

output "pubsub_dead_letter_subscription" {
  description = "Pull subscription that retains dead-lettered Pub/Sub messages (7 days)."
  value       = google_pubsub_subscription.dead_letter_pull.name
}

output "pubsub_subscription_worker_push" {
  value = var.enable_worker_push_subscription ? google_pubsub_subscription.worker_push[0].name : null
}

output "pubsub_subscription_worker_push_commands" {
  value = var.enable_worker_push_subscription ? google_pubsub_subscription.worker_push_commands[0].name : null
}

output "worker_push_endpoint" {
  description = "Resolved Pub/Sub push URL for the worker (empty when push subs disabled)."
  value       = local.worker_push_endpoint_effective
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
