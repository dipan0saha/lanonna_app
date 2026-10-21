locals {
  monitoring_notification_channel_ids = var.enable_platform_monitoring ? [
    for ch in google_monitoring_notification_channel.email : ch.id
  ] : []
}

resource "google_monitoring_notification_channel" "email" {
  for_each = var.enable_platform_monitoring ? toset(var.monitoring_notification_emails) : toset([])

  project      = var.project_id
  display_name = "La Nonna ops (${var.environment}) — ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }

  depends_on = [google_project_service.apis]
}

locals {
  api_health_host = trim(trimspace(var.monitoring_api_host), "/")
}

resource "google_monitoring_uptime_check_config" "api_health" {
  count = var.enable_platform_monitoring && local.api_health_host != "" ? 1 : 0

  project      = var.project_id
  display_name = "API /health (${var.environment})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/health"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = local.api_health_host
    }
  }

  depends_on = [google_project_service.apis]
}

# Alert when dead-lettered async commands accumulate (#62).
resource "google_monitoring_alert_policy" "async_commands_dead_letter_depth" {
  count = var.enable_worker_push_subscription ? 1 : 0

  project      = var.project_id
  display_name = "Pub/Sub async-commands dead-letter depth (${var.environment})"
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_notification_channel_ids

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

resource "google_monitoring_alert_policy" "cloud_run_5xx_rate" {
  count = var.enable_platform_monitoring ? 1 : 0

  project      = var.project_id
  display_name = "Cloud Run API 5xx rate (${var.environment})"
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_notification_channel_ids

  conditions {
    display_name = "5xx fraction on ${var.api_cloud_run_service_name}"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.api_cloud_run_service_name}"
        AND metric.type = "run.googleapis.com/request_count"
        AND metric.labels.response_code_class = "5xx"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.monitoring_cloud_run_5xx_rate_threshold
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      denominator_filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.api_cloud_run_service_name}"
        AND metric.type = "run.googleapis.com/request_count"
      EOT

      denominator_aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "cloud_run_p95_latency" {
  count = var.enable_platform_monitoring ? 1 : 0

  project      = var.project_id
  display_name = "Cloud Run API p95 latency (${var.environment})"
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_notification_channel_ids

  conditions {
    display_name = "p95 latency on ${var.api_cloud_run_service_name}"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.api_cloud_run_service_name}"
        AND metric.type = "run.googleapis.com/request_latencies"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.monitoring_cloud_run_p95_latency_ms
      duration        = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "api_uptime_check_failing" {
  count = var.enable_platform_monitoring && local.api_health_host != "" ? 1 : 0

  project      = var.project_id
  display_name = "API uptime check failing (${var.environment})"
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_notification_channel_ids

  conditions {
    display_name = "Uptime check ${google_monitoring_uptime_check_config.api_health[0].display_name}"

    condition_threshold {
      filter = <<-EOT
        resource.type = "uptime_check"
        AND metric.type = "monitoring.googleapis.com/uptime_check/check_passed"
        AND metric.labels.check_id = "${google_monitoring_uptime_check_config.api_health[0].uptime_check_id}"
      EOT

      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_cpu" {
  count = var.enable_platform_monitoring ? 1 : 0

  project      = var.project_id
  display_name = "Cloud SQL CPU high (${var.environment})"
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_notification_channel_ids

  conditions {
    display_name = "CPU on ${var.sql_instance_name}"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.database_id = "${var.project_id}:${var.sql_instance_name}"
        AND metric.type = "cloudsql.googleapis.com/database/cpu/utilization"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.monitoring_cloud_sql_cpu_threshold
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_disk" {
  count = var.enable_platform_monitoring ? 1 : 0

  project      = var.project_id
  display_name = "Cloud SQL disk high (${var.environment})"
  combiner     = "OR"
  enabled      = true

  notification_channels = local.monitoring_notification_channel_ids

  conditions {
    display_name = "Disk on ${var.sql_instance_name}"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.database_id = "${var.project_id}:${var.sql_instance_name}"
        AND metric.type = "cloudsql.googleapis.com/database/disk/utilization"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.monitoring_cloud_sql_disk_threshold
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}
