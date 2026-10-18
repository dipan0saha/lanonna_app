"""Signed download URLs for objects named in a baby export.

V4 signed URLs last at most seven days. The export JSON itself is still
downloaded through the API's short-lived URL; these links are only for the
media named inside that file. See docs/engineering/development.md.
"""

from __future__ import annotations

import threading
from datetime import timedelta
from typing import Any

from lanonna_worker.config import settings

# GCS V4 maximum expiration.
EXPORT_MEDIA_URL_TTL_SECONDS = 7 * 24 * 60 * 60

_CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
_TOKEN_URI = "https://oauth2.googleapis.com/token"


def signing_service_account() -> str:
    configured = settings.gcs_signing_service_account.strip()
    if configured:
        return configured
    return f"lanonna-worker@{settings.gcp_project_id}.iam.gserviceaccount.com"


class ExportUrlSigner:
    """One credentials object, storage client and keep-alive IAM session per process.

    Every signature is an IAM ``signBlob`` call (no key files). Building the
    client and refreshing a token once, instead of per object, leaves one
    round trip on a warm connection per media link.
    """

    def __init__(self, project: str, service_account_email: str) -> None:
        import google.auth
        import requests
        from google.auth import iam
        from google.auth.transport import requests as google_requests
        from google.cloud import storage
        from google.oauth2 import service_account

        credentials, _ = google.auth.default(scopes=[_CLOUD_PLATFORM_SCOPE])
        request = google_requests.Request(session=requests.Session())
        # Signs as ``service_account_email``; the runtime token is refreshed
        # only when it has expired.
        self._signing_credentials = service_account.Credentials(
            iam.Signer(request, credentials, service_account_email),
            service_account_email,
            _TOKEN_URI,
        )
        self._client = storage.Client(project=project, credentials=credentials)

    def sign(self, bucket: str, object_name: str) -> str:
        blob = self._client.bucket(bucket).blob(object_name)
        return blob.generate_signed_url(
            version="v4",
            expiration=timedelta(seconds=EXPORT_MEDIA_URL_TTL_SECONDS),
            method="GET",
            credentials=self._signing_credentials,
        )


_signer: ExportUrlSigner | None = None
_signer_lock = threading.Lock()


def _export_signer() -> ExportUrlSigner:
    global _signer
    with _signer_lock:
        if _signer is None:
            _signer = ExportUrlSigner(settings.gcp_project_id, signing_service_account())
        return _signer


def reset_export_signer(signer: Any = None) -> None:
    """Tests: drop (or replace) the process signer."""
    global _signer
    with _signer_lock:
        _signer = signer


def sign_export_read_url(bucket: str, object_name: str) -> str:
    """V4 GET URL for one object. Caller must not log the result (it is a credential)."""
    return _export_signer().sign(bucket, object_name)
