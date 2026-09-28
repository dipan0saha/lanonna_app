resource "google_firebase_project" "default" {
  count = var.enable_firebase ? 1 : 0

  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}
