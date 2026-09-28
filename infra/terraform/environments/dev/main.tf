locals {
  standard_apis = [
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
  ]
}

module "platform" {
  source = "../../modules/platform"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  apis         = local.standard_apis

  bucket_display    = "lanonna-dev-display"
  bucket_thumbnails = "lanonna-dev-thumbnails"

  sql_tier         = "db-custom-1-3840"
  sql_disk_gb      = 10
  sql_availability = "ZONAL"

  create_automation_sa      = true
  manage_sql_app_password   = false
  enable_firebase           = true
}
