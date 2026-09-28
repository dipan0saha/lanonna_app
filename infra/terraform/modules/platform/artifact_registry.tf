resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = var.artifact_repository_id
  description   = "La Nonna container images (${var.environment})"
  format        = "DOCKER"
  project       = var.project_id

  labels = {
    environment = var.environment
  }

  depends_on = [google_project_service.apis]
}
