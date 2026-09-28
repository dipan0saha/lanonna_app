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
  default = "db-custom-2-7680"
}

variable "sql_disk_gb" {
  type    = number
  default = 20
}
