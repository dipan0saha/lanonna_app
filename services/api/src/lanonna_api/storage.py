from __future__ import annotations

import uuid
from datetime import timedelta

import google.auth
from google.auth.transport import requests as google_requests
from google.cloud import storage

from lanonna_api.config import settings


def mint_display_upload_url(
    firebase_uid: str,
    content_type: str = "image/jpeg",
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    """V4 signed PUT URL for the display bucket (Cloud Run / no local SA key)."""
    if content_type not in settings.display_allowed_content_types:
        raise ValueError(f"Unsupported content type: {content_type}")

    object_name = f"smoke/{firebase_uid}/{uuid.uuid4().hex}.jpg"
    credentials, _ = google.auth.default()
    auth_request = google_requests.Request()
    credentials.refresh(auth_request)

    client = storage.Client(project=settings.gcp_project_id, credentials=credentials)
    blob = client.bucket(settings.display_bucket).blob(object_name)

    url = blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=15),
        method="PUT",
        content_type=content_type,
        service_account_email=settings.gcs_signing_service_account,
        access_token=credentials.token,
        headers={"x-goog-content-length-range": f"0,{max_bytes}"},
    )

    return {
        "upload_url": url,
        "object_path": object_name,
        "bucket": settings.display_bucket,
        "content_type": content_type,
        "max_bytes": max_bytes,
        "expires_in_seconds": 900,
    }
