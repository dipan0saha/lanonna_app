variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "bucket_display" {
  type = string
}

variable "bucket_thumbnails" {
  type = string
}

variable "sql_tier" {
  type    = string
  default = "db-custom-1-3840"
}

variable "sql_disk_gb" {
  type    = number
  default = 10
}

variable "sql_disk_autoresize_limit" {
  type        = number
  default     = 20
  description = "Max PD-SSD size (GB) when autoresize grows the instance."
}

variable "sql_availability" {
  type        = string
  default     = "ZONAL"
  description = "ZONAL for launch cost; set REGIONAL for HA when ready."
}

variable "monitoring_notification_emails" {
  type        = list(string)
  default     = []
  description = "Ops notification emails (set in gitignored terraform.tfvars)."
}

variable "monitoring_api_host" {
  type        = string
  default     = ""
  description = "API hostname for /health uptime checks; set after first API deploy (see operations.md)."
}
