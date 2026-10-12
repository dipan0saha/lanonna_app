# Alert when dead-lettered async commands accumulate (#62). Wire notification
# channels in Cloud Console when ops email/Slack is ready.
resource "google_monitoring_alert_policy" "async_commands_dead_letter_depth" {
  count = var.enable_worker_push_subscription ? 1 : 0

  project      = var.project_id
  display_name = "Pub/Sub async-commands dead-letter depth (${var.environment})"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Undelivered messages on ${google_pubsub_subscription.dead_letter_pull.name}"

    condition_threshold {
      filter = <<-EOT
        resource.type = "pubsub_subscription"
        AND resource.labels.subscription_id = "${google_pubsub_subscription.dead_letter_pull.name}"
        AND metric.type = "pubsub.googleapis.com/subscription/num_undelivered_messages"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  documentation {
    content = "Messages landed on the async-commands dead-letter subscription. Inspect with gcloud pubsub subscriptions pull on ${google_pubsub_subscription.dead_letter_pull.name} and check invitation email_delivery_status."
  }
}
