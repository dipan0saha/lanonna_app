locals {
  standard_apis = [
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "compute.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudbilling.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    # App Check (Play Integrity provider): Firebase decodes the client's integrity
    # token in this project, so the Play Integrity API must be on here.
    "firebaseappcheck.googleapis.com",
    "playintegrity.googleapis.com",
  ]
}

module "platform" {
  source = "../../modules/platform"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  apis        = local.standard_apis

  bucket_display    = "lanonna-dev-display"
  bucket_thumbnails = "lanonna-dev-thumbnails"

  sql_tier         = "db-custom-1-3840"
  sql_disk_gb      = 10
  sql_availability = "ZONAL"

  create_automation_sa    = true
  manage_sql_app_password = false
  enable_firebase         = true

  enable_worker_push_subscription = true
  # worker_push_endpoint: leave empty to use the live Cloud Run `worker` URL (see worker_push.tf).

  # Legacy import-only secret (unused by Cloud Run). Keep in dev state so e25c3fd does not plan a destroy.
  secret_ids = [
    "database-url",
    "db-lanonna-app-password",
    "db-postgres-root-password",
    "mailjet-api-key",
    "mailjet-api-secret",
    "admin-api-key",
  ]

  enable_platform_monitoring     = var.enable_platform_monitoring
  monitoring_notification_emails = var.monitoring_notification_emails
  monitoring_api_host            = var.monitoring_api_host
}
