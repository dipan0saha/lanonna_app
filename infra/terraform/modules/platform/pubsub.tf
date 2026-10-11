resource "google_pubsub_topic" "upload" {
  name    = var.pubsub_topic_upload
  project = var.project_id

  labels = {
    environment = var.environment
  }

  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic" "async_commands" {
  name    = var.pubsub_topic_commands
  project = var.project_id

  labels = {
    environment = var.environment
  }

  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic" "dead_letter" {
  name    = "${var.pubsub_topic_commands}-dlq"
  project = var.project_id

  labels = {
    environment = var.environment
  }

  depends_on = [google_project_service.apis]
}

# GCS service agent must publish object events to the upload topic only.
resource "google_pubsub_topic_iam_member" "gcs_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.upload.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "api_commands_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.async_commands.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_pubsub_topic_iam_member" "pubsub_dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription" "worker_push" {
  count = var.enable_worker_push_subscription ? 1 : 0

  name    = var.worker_push_subscription_name
  project = var.project_id
  topic   = google_pubsub_topic.upload.name

  ack_deadline_seconds = 120

  push_config {
    push_endpoint = var.worker_push_endpoint

    oidc_token {
      service_account_email = google_service_account.worker.email
    }
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  labels = {
    environment = var.environment
  }
}

resource "google_pubsub_subscription" "worker_push_commands" {
  count = var.enable_worker_push_subscription ? 1 : 0

  name    = var.worker_push_commands_subscription_name
  project = var.project_id
  topic   = google_pubsub_topic.async_commands.name

  ack_deadline_seconds = 120

  push_config {
    push_endpoint = var.worker_push_endpoint

    oidc_token {
      service_account_email = google_service_account.worker.email
    }
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  labels = {
    environment = var.environment
  }
}

resource "google_pubsub_subscription_iam_member" "worker_commands_subscriber" {
  count        = var.enable_worker_push_subscription ? 1 : 0
  project      = var.project_id
  subscription = google_pubsub_subscription.worker_push_commands[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_pubsub_subscription_iam_member" "worker_push_subscriber" {
  count        = var.enable_worker_push_subscription ? 1 : 0
  project      = var.project_id
  subscription = google_pubsub_subscription.worker_push[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.worker.email}"
}
