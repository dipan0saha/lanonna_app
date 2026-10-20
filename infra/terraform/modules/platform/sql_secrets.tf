# When manage_sql_app_password is true (fresh prod), persist the generated app password
# to Secret Manager. Dev keeps manage_sql_app_password=false so existing secret versions
# are never created or rotated by Terraform.

locals {
  sql_connection_name = "${var.project_id}:${var.region}:${var.sql_instance_name}"
  database_url = var.manage_sql_app_password ? format(
    "postgresql://%s:%s@/%s?host=/cloudsql/%s",
    var.sql_app_user,
    urlencode(random_password.sql_app[0].result),
    var.sql_database_name,
    local.sql_connection_name,
  ) : null
}

resource "google_secret_manager_secret_version" "db_lanonna_app_password" {
  count = var.manage_sql_app_password ? 1 : 0

  secret      = google_secret_manager_secret.app["db-lanonna-app-password"].id
  secret_data = random_password.sql_app[0].result
}

resource "google_secret_manager_secret_version" "database_url" {
  count = var.manage_sql_app_password ? 1 : 0

  secret      = google_secret_manager_secret.app["database-url"].id
  secret_data = local.database_url
}
