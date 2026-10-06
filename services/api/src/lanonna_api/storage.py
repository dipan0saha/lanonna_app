from __future__ import annotations

import uuid
from datetime import timedelta
from uuid import UUID

import google.auth
from google.auth.transport import requests as google_requests
from google.cloud import storage

from lanonna_api.config import settings


def mint_user_avatar_upload_url(
    firebase_uid: str,
    content_type: str = "image/jpeg",
    byte_length: int = 0,
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    """V4 signed PUT for a user profile avatar in the display bucket."""
    if content_type not in settings.display_allowed_content_types:
        raise ValueError(f"Unsupported content type: {content_type}")
    if byte_length <= 0 or byte_length > max_bytes:
        raise ValueError("Display asset exceeds maximum size.")

    ext = "webp" if content_type == "image/webp" else "jpg"
    object_name = f"avatars/users/{firebase_uid}/{uuid.uuid4().hex}.{ext}"
    return _sign_put(object_name, content_type, max_bytes)


def mint_baby_avatar_upload_url(
    baby_profile_id: UUID,
    content_type: str = "image/jpeg",
    byte_length: int = 0,
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    """V4 signed PUT for a baby profile avatar in the display bucket."""
    if content_type not in settings.display_allowed_content_types:
        raise ValueError(f"Unsupported content type: {content_type}")
    if byte_length <= 0 or byte_length > max_bytes:
        raise ValueError("Display asset exceeds maximum size.")

    ext = "webp" if content_type == "image/webp" else "jpg"
    object_name = f"avatars/babies/{baby_profile_id}/{uuid.uuid4().hex}.{ext}"
    return _sign_put(object_name, content_type, max_bytes)


def mint_display_upload_for_object(
    object_name: str,
    content_type: str = "image/jpeg",
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    if content_type not in settings.display_allowed_content_types:
        raise ValueError(f"Unsupported content type: {content_type}")
    if not object_name.startswith("display/"):
        raise ValueError("Upload path must be under display/")
    return _sign_put(object_name, content_type, max_bytes)


def _sign_put(
    object_name: str,
    content_type: str,
    max_bytes: int,
) -> dict[str, str | int]:
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
        "required_headers": {
            "Content-Type": content_type,
            "x-goog-content-length-range": f"0,{max_bytes}",
        },
    }


def mint_signed_read_url(bucket: str, object_name: str, minutes: int = 15) -> str:
    credentials, _ = google.auth.default()
    auth_request = google_requests.Request()
    credentials.refresh(auth_request)
    client = storage.Client(project=settings.gcp_project_id, credentials=credentials)
    blob = client.bucket(bucket).blob(object_name)
    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=minutes),
        method="GET",
        service_account_email=settings.gcs_signing_service_account,
        access_token=credentials.token,
    )
