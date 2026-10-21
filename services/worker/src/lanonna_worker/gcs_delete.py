"""GCS object deletion for storage cleanup jobs."""

from __future__ import annotations

import logging
from collections.abc import Iterable

from google.api_core.exceptions import NotFound
from google.cloud import storage

from lanonna_worker.config import settings

logger = logging.getLogger("lanonna.worker.gcs_delete")


class GcsDeleteError(RuntimeError):
    """Raised when a delete should be retried (transient or unknown)."""


def _client() -> storage.Client:
    return storage.Client()


def delete_object(bucket_name: str, object_name: str) -> bool:
    """Delete one object. Returns True if deleted, False if already absent."""
    try:
        blob = _client().bucket(bucket_name).blob(object_name)
        blob.delete()
        return True
    except NotFound:
        return False
    except Exception as exc:
        raise GcsDeleteError(f"delete failed bucket={bucket_name}") from exc


def delete_prefix(bucket_name: str, prefix: str) -> int:
    """Delete every object under ``prefix``. Returns count deleted."""
    if not prefix:
        return 0
    try:
        bucket = _client().bucket(bucket_name)
        deleted = 0
        for blob in bucket.list_blobs(prefix=prefix):
            try:
                blob.delete()
                deleted += 1
            except NotFound:
                continue
            except Exception as exc:
                raise GcsDeleteError(f"prefix delete failed bucket={bucket_name}") from exc
        return deleted
    except GcsDeleteError:
        raise
    except Exception as exc:
        raise GcsDeleteError(f"list failed bucket={bucket_name}") from exc


def delete_photo_paths(
    display_path: str | None,
    thumb_path: str | None,
) -> int:
    count = 0
    if display_path:
        if delete_object(settings.display_bucket, display_path):
            count += 1
    if thumb_path:
        if delete_object(settings.thumbnails_bucket, thumb_path):
            count += 1
    return count


def delete_display_paths(paths: Iterable[str]) -> int:
    count = 0
    for path in paths:
        if path and delete_object(settings.display_bucket, path):
            count += 1
    return count
