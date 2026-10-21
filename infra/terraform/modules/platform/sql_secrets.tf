# When manage_sql_app_password is true (fresh prod), persist the generated app password
# to Secret Manager. Dev keeps manage_sql_app_password=false so existing secret versions
# are never created or rotated by Terraform.
#
# The random_password value is stored in Terraform state; see open-gaps.md (M-60).

resource "google_secret_manager_secret_version" "db_lanonna_app_password" {
  count = var.manage_sql_app_password ? 1 : 0

  secret      = google_secret_manager_secret.app["db-lanonna-app-password"].id
  secret_data = random_password.sql_app[0].result
}
