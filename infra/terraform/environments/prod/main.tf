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
  ]
}

module "platform" {
  source = "../../modules/platform"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  apis        = local.standard_apis

  bucket_display    = var.bucket_display
  bucket_thumbnails = var.bucket_thumbnails

  sql_tier         = var.sql_tier
  sql_disk_gb      = var.sql_disk_gb
  sql_availability = "ZONAL"

  create_automation_sa    = false
  manage_sql_app_password = true
  enable_firebase         = true
}
