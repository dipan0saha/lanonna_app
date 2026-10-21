variable "project_id" {
  type    = string
  default = "lanonna-dev"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "enable_platform_monitoring" {
  type        = bool
  default     = false
  description = "When true, create uptime checks and alert policies (set in gitignored terraform.tfvars)."
}

variable "monitoring_notification_emails" {
  type        = list(string)
  default     = []
  description = "Ops notification emails (gitignored tfvars only)."
}

variable "monitoring_api_host" {
  type        = string
  default     = ""
  description = "API hostname for /health uptime checks when monitoring is enabled."
}
