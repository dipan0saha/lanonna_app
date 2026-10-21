"""GCS deletes for storage cleanup jobs. An already-absent object counts as done,
so a job can be re-run safely."""

from __future__ import annotations

from collections.abc import Iterable
from functools import lru_cache

from google.api_core.exceptions import NotFound
from google.cloud import storage

from lanonna_worker.config import settings
from lanonna_worker.thumbnails import thumbnail_path_for_display


class GcsDeleteError(RuntimeError):
    """A delete failed and the job should be retried."""


@lru_cache(maxsize=1)
def _client() -> storage.Client:
    return storage.Client(project=settings.gcp_project_id)


def delete_object(bucket_name: str, object_name: str) -> bool:
    """Delete one object. Returns True if deleted, False if already absent."""
    try:
        _client().bucket(bucket_name).blob(object_name).delete()
        return True
    except NotFound:
        return False
    except Exception as exc:
        raise GcsDeleteError(f"delete failed bucket={bucket_name}") from exc


def delete_prefix(bucket_name: str, prefix: str) -> int:
    """Delete every object under an owned folder (``exports/{id}/``,
    ``avatars/users/{uid}/``). Returns the count deleted.

    ``prefix`` must end with ``/``, have at least two segments and none empty, so
    ``avatars/users/a/`` never matches ``avatars/users/ab/...`` or a parent folder.
    """
    segments = prefix[:-1].split("/")
    if not prefix.endswith("/") or len(segments) < 2 or not all(segments):
        raise ValueError("storage cleanup prefix must be a complete folder path")
    try:
        blobs = list(_client().bucket(bucket_name).list_blobs(prefix=prefix))
    except Exception as exc:
        raise GcsDeleteError(f"list failed bucket={bucket_name}") from exc
    return sum(delete_object(bucket_name, blob.name) for blob in blobs)


def delete_photo_paths(display_path: str | None, thumb_path: str | None) -> int:
    """Delete a photo's display object and thumbnail. A photo still processing has
    no ``thumb_path`` yet, so the thumbnail key is derived from the display key."""
    count = 0
    if display_path:
        count += delete_object(settings.display_bucket, display_path)
        thumb_path = thumb_path or thumbnail_path_for_display(display_path)
    if thumb_path:
        count += delete_object(settings.thumbnails_bucket, thumb_path)
    return count


def delete_display_paths(paths: Iterable[str]) -> int:
    return sum(delete_object(settings.display_bucket, path) for path in paths if path)
