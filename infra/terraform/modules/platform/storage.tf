resource "google_storage_bucket" "display" {
  name     = var.bucket_display
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true

  # Flutter web / local dev signed PUT uploads (mobile native uploads do not use CORS).
  cors {
    origin          = var.display_bucket_cors_origins
    method          = ["GET", "PUT", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Content-Length", "x-goog-content-length-range", "x-goog-resumable"]
    max_age_seconds = 3600
  }

  labels = {
    environment = var.environment
    purpose     = "display"
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket" "thumbnails" {
  name     = var.bucket_thumbnails
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    purpose     = "thumbnails"
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_notification" "display_upload" {
  bucket         = google_storage_bucket.display.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.upload.id
  event_types    = ["OBJECT_FINALIZE"]

  depends_on = [
    google_pubsub_topic_iam_member.gcs_publisher,
  ]
}
