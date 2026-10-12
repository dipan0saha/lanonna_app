"""Signed download URLs for objects named in a baby export.

V4 signed URLs last at most seven days. The export JSON itself is still
downloaded through the API's short-lived URL; these links are only for the
media named inside that file. See docs/engineering/development.md.
"""

from __future__ import annotations

from datetime import timedelta

from lanonna_worker.config import settings

# GCS V4 maximum expiration.
EXPORT_MEDIA_URL_TTL_SECONDS = 7 * 24 * 60 * 60


def signing_service_account() -> str:
    configured = settings.gcs_signing_service_account.strip()
    if configured:
        return configured
    return f"lanonna-worker@{settings.gcp_project_id}.iam.gserviceaccount.com"


def sign_export_read_url(bucket: str, object_name: str) -> str:
    """V4 GET URL for one object. Caller must not log the result (it is a credential)."""
    import google.auth
    from google.auth.transport import requests as google_requests
    from google.cloud import storage

    credentials, _ = google.auth.default()
    credentials.refresh(google_requests.Request())
    client = storage.Client(project=settings.gcp_project_id, credentials=credentials)
    blob = client.bucket(bucket).blob(object_name)
    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(seconds=EXPORT_MEDIA_URL_TTL_SECONDS),
        method="GET",
        service_account_email=signing_service_account(),
        access_token=credentials.token,
    )
