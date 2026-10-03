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

variable "pubsub_subscription_worker" {
  type    = string
  default = "photo-upload-finalized-worker"
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

variable "worker_push_endpoint" {
  type        = string
  default     = ""
  description = "Full URL e.g. https://worker-….run.app/pubsub/push"
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

variable "sql_availability" {
  type        = string
  default     = "ZONAL"
  description = "ZONAL or REGIONAL (HA)."
}

variable "create_automation_sa" {
  type        = bool
  default     = false
  description = "Dev-only: broad SA for local/agent automation (not for prod)."
}

variable "manage_sql_app_password" {
  type        = bool
  default     = false
  description = "When false, imported DB user password is not rotated by Terraform."
}

variable "enable_firebase" {
  type    = bool
  default = true
}

variable "secret_ids" {
  type = list(string)
  default = [
    "database-url",
    "db-lanonna-app-password",
    "db-postgres-root-password",
    "mailjet-api-key",
    "mailjet-api-secret",
    "admin-api-key",
  ]
  description = "Secret Manager secret IDs (containers only; versions set outside TF or via apply on fresh env)."
}
