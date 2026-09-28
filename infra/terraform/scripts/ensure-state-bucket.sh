#!/usr/bin/env bash
# Create Terraform remote state bucket (run once per environment).
set -euo pipefail

PROJECT_ID="${1:?usage: ensure-state-bucket.sh <project-id> <bucket-name>}"
BUCKET="${2:?}"

if gcloud storage buckets describe "gs://${BUCKET}" &>/dev/null; then
  echo "Bucket gs://${BUCKET} already exists."
  exit 0
fi

gcloud storage buckets create "gs://${BUCKET}" \
  --project="${PROJECT_ID}" \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://${BUCKET}" --versioning

echo "Created state bucket gs://${BUCKET}"
