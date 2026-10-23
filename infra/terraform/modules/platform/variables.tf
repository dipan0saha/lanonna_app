variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Primary region for regional resources."
}

variable "environment" {
  type        = string
  description = "Environment label (dev, prod)."
}

variable "apis" {
  type        = list(string)
  description = "Service APIs to enable on the project."
}

variable "bucket_display" {
  type        = string
  description = "Globally unique GCS bucket for display assets."
}

variable "bucket_thumbnails" {
  type        = string
  description = "Globally unique GCS bucket for thumbnails."
}

variable "pubsub_topic_upload" {
  type    = string
  default = "photo-upload-finalized"
}

variable "pubsub_topic_commands" {
  type        = string
  default     = "lanonna-async-commands"
  description = "API and Scheduler async job messages (invite email, notify, export, cron payloads)."
}

variable "enable_worker_push_subscription" {
  type        = bool
  default     = false
  description = "When true, manage Pub/Sub push subscription to Cloud Run worker (worker must exist)."
}

variable "worker_push_subscription_name" {
  type    = string
  default = "photo-upload-finalized-push-dev"
}

variable "worker_push_commands_subscription_name" {
  type    = string
  default = "lanonna-async-commands-push-dev"
}

variable "worker_push_endpoint" {
  type        = string
  default     = ""
  description = "Full URL e.g. https://worker-….run.app/pubsub/push. When empty and push subs are enabled, read from the live Cloud Run service (worker_cloud_run_service_name)."
}

variable "worker_cloud_run_service_name" {
  type        = string
  default     = "worker"
  description = "Cloud Run service name for push endpoint resolution and run.invoker bindings."
}

variable "display_bucket_cors_origins" {
  type        = list(string)
  default     = ["http://localhost:7357", "http://localhost:8080", "http://127.0.0.1:7357"]
  description = "CORS origins for browser uploads to the display bucket."
}

variable "artifact_repository_id" {
  type    = string
  default = "lanonna"
}

variable "sql_instance_name" {
  type    = string
  default = "lanonna-db"
}

variable "sql_database_name" {
  type    = string
  default = "lanonna"
}

variable "sql_app_user" {
  type    = string
  default = "lanonna_app"
}

variable "sql_tier" {
  type        = string
  description = "Cloud SQL machine tier, e.g. db-custom-1-3840."
}

variable "sql_disk_gb" {
  type    = number
  default = 10
}

variable "sql_disk_autoresize" {
  type        = bool
  default     = true
  description = "Grow PD-SSD automatically when usage is high."
}

variable "sql_disk_autoresize_limit" {
  type        = number
  default     = null
  nullable    = true
  description = "Max disk size (GB) when autoresize is on; null means no cap."
}

variable "sql_transaction_log_retention_days" {
  type        = number
  default     = 7
  description = "Point-in-time recovery log retention (days)."
}

variable "sql_deletion_protection" {
  type        = bool
  default     = false
  description = "Terraform and API deletion protection for the Cloud SQL instance."
}

variable "sql_availability" {
  type        = string
  default     = "ZONAL"
  description = "ZONAL or REGIONAL (HA)."
}

variable "bucket_lifecycle_rules_enabled" {
  type        = bool
  default     = false
  description = "When true, apply GCS lifecycle rules on display/thumbnail buckets (no live object deletion)."
}

variable "bucket_versioning_enabled" {
  type        = bool
  default     = false
  description = "When true, enable object versioning on display/thumbnail buckets (required for noncurrent cleanup rules)."
}

variable "api_cloud_run_service_name" {
  type        = string
  default     = "api"
  description = "Cloud Run service name for Run metric alert filters."
}

variable "monitoring_api_host" {
  type        = string
  default     = ""
  description = "API hostname for HTTPS uptime checks (no scheme), e.g. api-xxx.run.app. When empty, uptime check resources are skipped."
}

variable "enable_platform_monitoring" {
  type        = bool
  default     = false
  description = "When true, create uptime checks and alert policies (opt-in on dev via tfvars)."
}

variable "monitoring_notification_emails" {
  type        = list(string)
  default     = []
  description = "Email addresses for Monitoring notification channels (set in gitignored tfvars)."
}

variable "monitoring_cloud_run_5xx_rate_threshold" {
  type        = number
  default     = 0.05
  description = "Alert when 5xx responses exceed this fraction of request count (over alignment window)."
}

variable "monitoring_worker_mailjet_failures_threshold" {
  type        = number
  default     = 5
  description = "Alert when the worker logs more than this many failed Mailjet sends in 15 minutes (#428)."
}

variable "monitoring_cloud_run_p95_latency_ms" {
  type        = number
  default     = 2000
  description = "Alert when Cloud Run request latency p95 exceeds this value (milliseconds)."
}

variable "monitoring_cloud_sql_cpu_threshold" {
  type        = number
  default     = 0.85
  description = "Alert when Cloud SQL CPU utilization exceeds this fraction."
}

variable "monitoring_cloud_sql_disk_threshold" {
  type        = number
  default     = 0.85
  description = "Alert when Cloud SQL disk utilization exceeds this fraction."
}

variable "create_automation_sa" {
  type        = bool
  default     = false
  description = "Dev-only: broad SA for local/agent automation (not for prod)."
}

variable "manage_sql_app_password" {
  type        = bool
  default     = false
  description = "When true (fresh prod), Terraform generates the app user password and writes a db-lanonna-app-password secret version. When false (dev import), SQL user password changes are ignored and no secret versions are managed."
}

variable "enable_firebase" {
  type    = bool
  default = true
}

variable "secret_ids" {
  type = list(string)
  default = [
    "db-lanonna-app-password",
    "db-postgres-root-password",
    "mailjet-api-key",
    "mailjet-api-secret",
    "admin-api-key",
  ]
  description = "Secret Manager secret IDs (containers only; versions set outside TF or via apply on fresh env)."
}
