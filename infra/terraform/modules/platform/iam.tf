data "google_project" "current" {
  project_id = var.project_id
}

resource "google_service_account" "api" {
  account_id   = "lanonna-api"
  display_name = "La Nonna Cloud Run API (${var.environment})"
  project      = var.project_id
}

resource "google_service_account" "worker" {
  account_id   = "lanonna-worker"
  display_name = "La Nonna Cloud Run worker (${var.environment})"
  project      = var.project_id
}

resource "google_service_account" "automation" {
  count = var.create_automation_sa ? 1 : 0

  account_id   = "lanonna-automation"
  display_name = "La Nonna automation (${var.environment}) — dev only"
  project      = var.project_id
}

locals {
  runtime_sas = {
    api    = google_service_account.api.email
    worker = google_service_account.worker.email
  }
}

resource "google_project_iam_member" "runtime_cloudsql_client" {
  for_each = local.runtime_sas

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "runtime_secret_accessor" {
  for_each = local.runtime_sas

  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${each.value}"
}

# Account delete (FR-SET-005): Firebase Admin delete_user on Cloud Run API.
resource "google_project_iam_member" "api_firebase_auth_admin" {
  project = var.project_id
  role    = "roles/firebaseauth.admin"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_storage_bucket_iam_member" "runtime_display_admin" {
  for_each = local.runtime_sas

  bucket = google_storage_bucket.display.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}

resource "google_storage_bucket_iam_member" "runtime_thumbnails_admin" {
  for_each = local.runtime_sas

  bucket = google_storage_bucket.thumbnails.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}

# Dev-only automation principal (prefer WIF + CI SA in prod).
resource "google_project_iam_member" "automation_editor" {
  count = var.create_automation_sa ? 1 : 0

  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.automation[0].email}"
}

resource "google_project_iam_member" "automation_sa_admin" {
  count = var.create_automation_sa ? 1 : 0

  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.automation[0].email}"
}

resource "google_project_iam_member" "automation_project_iam_admin" {
  count = var.create_automation_sa ? 1 : 0

  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.automation[0].email}"
}
