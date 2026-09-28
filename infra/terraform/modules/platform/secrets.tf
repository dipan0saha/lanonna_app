resource "google_secret_manager_secret" "app" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
  }

  depends_on = [google_project_service.apis]
}
