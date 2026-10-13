# Pub/Sub push → Cloud Run worker (service deployed outside this module).
data "google_cloud_run_v2_service" "worker_push_target" {
  count = var.enable_worker_push_subscription ? 1 : 0

  name     = var.worker_cloud_run_service_name
  location = var.region
  project  = var.project_id
}

locals {
  worker_push_endpoint_effective = !var.enable_worker_push_subscription ? "" : (
    trimspace(var.worker_push_endpoint) != "" ? trimspace(var.worker_push_endpoint) : (
      "${trimsuffix(data.google_cloud_run_v2_service.worker_push_target[0].uri, "/")}/pubsub/push"
    )
  )
}
