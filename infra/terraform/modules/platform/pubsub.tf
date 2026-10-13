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

locals {
  pubsub_service_agent         = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  pubsub_max_delivery_attempts = 12
}

# Dead-lettering needs the Pub/Sub service agent to publish to the DLQ topic and to
# acknowledge (subscribe on) each source subscription.
resource "google_pubsub_topic_iam_member" "pubsub_dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

# Without a subscription, dead-lettered messages are not retained (they cannot be inspected
# or replayed). Retain for 7 days; pull with `gcloud pubsub subscriptions pull` (operations.md).
resource "google_pubsub_subscription" "dead_letter_pull" {
  name    = "${google_pubsub_topic.dead_letter.name}-pull"
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"

  expiration_policy {
    ttl = "" # never expire
  }

  labels = {
    environment = var.environment
  }
}

resource "google_pubsub_subscription" "worker_push" {
  count = var.enable_worker_push_subscription ? 1 : 0

  name    = var.worker_push_subscription_name
  project = var.project_id
  topic   = google_pubsub_topic.upload.name

  ack_deadline_seconds = 300

  push_config {
    push_endpoint = local.worker_push_endpoint_effective

    oidc_token {
      service_account_email = google_service_account.worker.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = local.pubsub_max_delivery_attempts
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

  ack_deadline_seconds = 300

  push_config {
    push_endpoint = local.worker_push_endpoint_effective

    oidc_token {
      service_account_email = google_service_account.worker.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = local.pubsub_max_delivery_attempts
  }

  labels = {
    environment = var.environment
  }
}

# The worker receives HTTP push (OIDC) and never pulls, so it needs no subscriber role.
# Dead-lettering needs the Pub/Sub service agent to be a subscriber on each push subscription.
resource "google_pubsub_subscription_iam_member" "dead_letter_agent_subscriber_upload" {
  count        = var.enable_worker_push_subscription ? 1 : 0
  project      = var.project_id
  subscription = google_pubsub_subscription.worker_push[0].name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_service_agent
}

resource "google_pubsub_subscription_iam_member" "dead_letter_agent_subscriber_commands" {
  count        = var.enable_worker_push_subscription ? 1 : 0
  project      = var.project_id
  subscription = google_pubsub_subscription.worker_push_commands[0].name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_service_agent
}
