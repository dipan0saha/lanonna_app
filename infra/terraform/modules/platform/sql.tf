resource "google_sql_database_instance" "main" {
  name             = var.sql_instance_name
  database_version = "POSTGRES_16"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = var.sql_tier
    edition           = "ENTERPRISE"
    availability_type = var.sql_availability
    disk_type         = "PD_SSD"
    disk_size         = var.sql_disk_gb

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
    }

    ip_configuration {
      ipv4_enabled = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }

  deletion_protection = var.environment == "prod"

  depends_on = [google_project_service.apis]
}

resource "google_sql_database" "app" {
  name     = var.sql_database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "random_password" "sql_app" {
  count = var.manage_sql_app_password ? 1 : 0

  length  = 24
  special = false
}

resource "google_sql_user" "app" {
  name     = var.sql_app_user
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  password = var.manage_sql_app_password ? random_password.sql_app[0].result : "terraform-import-placeholder"

  lifecycle {
    # Passwords live in Secret Manager; avoid drift on imported dev.
    ignore_changes = [password]
  }
}
