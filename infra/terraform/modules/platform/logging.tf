# Invite accept tokens are query parameters on the HTTPS landing page and on
# GET /v1/invitations/preview. Request logs would store them. Application code
# does not log the token; this exclusion keeps the platform request logs from
# retaining it either.
resource "google_logging_project_exclusion" "invite_token_request_urls" {
  name        = "exclude-invite-token-request-urls"
  project     = var.project_id
  description = "Drop request logs whose URL contains an invitation token."

  filter = <<-EOT
    httpRequest.requestUrl:"/v1/invitations/preview" OR httpRequest.requestUrl:"/invite?"
  EOT
}
