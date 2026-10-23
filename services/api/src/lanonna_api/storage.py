"""V4 signed GCS URLs through one process-wide signer.

Cloud Run has no service-account key, so every signature comes from the IAM
Credentials ``signBlob`` API (no key files). ``GcsUrlSigner`` keeps, per
process:

* one credentials object, refreshed only when its token expires;
* one storage client and one keep-alive HTTP session to IAM, so a signature
  is a single round trip on a warm connection;
* a bounded cache of read URLs per object. A read URL is signed for
  ``READ_URL_TTL`` (900 s, unchanged) and served again only while it is less
  than ``READ_URL_REUSE`` old, so every URL a client receives still has at
  least ``READ_URL_TTL - READ_URL_REUSE`` (10 minutes) to live;
* a small thread pool that signs a page's cache misses in parallel.

Upload (PUT) URLs are unique per object and never cached.
"""

from __future__ import annotations

import logging
import threading
import time
import uuid
from collections import OrderedDict
from collections.abc import Callable, Sequence
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from typing import Protocol
from uuid import UUID

from lanonna_api.config import settings
from lanonna_api.domain.errors import ErrorCode, InvalidInputError
from lanonna_api.domain.storage_references import baby_avatar_prefix, user_avatar_prefix

READ_URL_TTL = timedelta(seconds=900)
UPLOAD_URL_TTL = timedelta(seconds=900)
READ_URL_REUSE = timedelta(seconds=300)
READ_URL_CACHE_MAX_ENTRIES = 4096
SIGN_CONCURRENCY = 8

logger = logging.getLogger(__name__)

_CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"
_TOKEN_URI = "https://oauth2.googleapis.com/token"

ObjectRef = tuple[str, str]  # (bucket, object name)


class SigningBackend(Protocol):
    def sign(
        self,
        bucket: str,
        object_name: str,
        *,
        method: str,
        expiration: timedelta,
        content_type: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> str: ...


class IamSigningBackend:
    """Signs with application default credentials through IAM ``signBlob``."""

    def __init__(self, project: str, service_account_email: str) -> None:
        import google.auth
        import requests
        from google.auth import iam
        from google.auth.transport import requests as google_requests
        from google.cloud import storage
        from google.oauth2 import service_account
        from requests.adapters import HTTPAdapter

        credentials, _ = google.auth.default(scopes=[_CLOUD_PLATFORM_SCOPE])
        session = requests.Session()
        session.mount(
            "https://",
            HTTPAdapter(pool_connections=2, pool_maxsize=SIGN_CONCURRENCY * 2),
        )
        self._request = google_requests.Request(session=session)
        self._credentials = credentials
        # A signing-only credentials object: sign_bytes() calls IAM signBlob
        # as ``service_account_email``, authenticated by the runtime identity
        # (token refreshed by the signer only when it has expired).
        self._signing_credentials = service_account.Credentials(
            iam.Signer(self._request, credentials, service_account_email),
            service_account_email,
            _TOKEN_URI,
        )
        self._client = storage.Client(project=project, credentials=credentials)

    def warm(self) -> None:
        """Fetch the first access token so the first request does not."""
        if not self._credentials.valid:
            self._credentials.refresh(self._request)

    def sign(
        self,
        bucket: str,
        object_name: str,
        *,
        method: str,
        expiration: timedelta,
        content_type: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> str:
        blob = self._client.bucket(bucket).blob(object_name)
        return blob.generate_signed_url(
            version="v4",
            expiration=expiration,
            method=method,
            content_type=content_type,
            headers=headers,
            credentials=self._signing_credentials,
        )


class GcsUrlSigner:
    def __init__(
        self,
        backend_factory: Callable[[], SigningBackend],
        *,
        clock: Callable[[], float] = time.monotonic,
        read_ttl: timedelta = READ_URL_TTL,
        read_reuse: timedelta = READ_URL_REUSE,
        max_entries: int = READ_URL_CACHE_MAX_ENTRIES,
        concurrency: int = SIGN_CONCURRENCY,
    ) -> None:
        if read_reuse >= read_ttl:
            raise ValueError("read_reuse must be shorter than read_ttl")
        self._backend_factory = backend_factory
        self._backend: SigningBackend | None = None
        self._clock = clock
        self._read_ttl = read_ttl
        self._read_reuse_seconds = read_reuse.total_seconds()
        self._max_entries = max_entries
        self._concurrency = concurrency
        self._executor: ThreadPoolExecutor | None = None
        self._lock = threading.Lock()
        # (bucket, object) -> (url, reuse_until on the monotonic clock)
        self._cache: OrderedDict[ObjectRef, tuple[str, float]] = OrderedDict()

    def backend(self) -> SigningBackend:
        with self._lock:
            if self._backend is None:
                self._backend = self._backend_factory()
            return self._backend

    def read_url(self, bucket: str, object_name: str) -> str:
        return self.read_urls([(bucket, object_name)])[0]

    def read_urls(self, refs: Sequence[ObjectRef]) -> list[str]:
        """Signed GET URLs in input order; cache hits cost nothing."""
        now = self._clock()
        found: dict[ObjectRef, str] = {}
        misses: list[ObjectRef] = []
        with self._lock:
            for ref in dict.fromkeys(refs):
                entry = self._cache.get(ref)
                if entry is not None and entry[1] > now:
                    self._cache.move_to_end(ref)
                    found[ref] = entry[0]
                else:
                    misses.append(ref)
        if misses:
            # Measured before signing, so reuse never outlives signing time + reuse.
            reuse_until = self._clock() + self._read_reuse_seconds
            signed = self._sign_reads(misses)
            with self._lock:
                for ref, url in zip(misses, signed):
                    self._cache[ref] = (url, reuse_until)
                    self._cache.move_to_end(ref)
                    found[ref] = url
                while len(self._cache) > self._max_entries:
                    self._cache.popitem(last=False)
        return [found[ref] for ref in refs]

    def upload_url(
        self,
        bucket: str,
        object_name: str,
        *,
        content_type: str,
        headers: dict[str, str],
    ) -> str:
        return self.backend().sign(
            bucket,
            object_name,
            method="PUT",
            expiration=UPLOAD_URL_TTL,
            content_type=content_type,
            headers=headers,
        )

    def clear(self) -> None:
        with self._lock:
            self._cache.clear()

    def _sign_reads(self, refs: list[ObjectRef]) -> list[str]:
        backend = self.backend()

        def sign(ref: ObjectRef) -> str:
            return backend.sign(ref[0], ref[1], method="GET", expiration=self._read_ttl)

        if len(refs) == 1:
            return [sign(refs[0])]
        return list(self._pool().map(sign, refs))

    def _pool(self) -> ThreadPoolExecutor:
        with self._lock:
            if self._executor is None:
                self._executor = ThreadPoolExecutor(
                    max_workers=self._concurrency, thread_name_prefix="gcs-sign"
                )
            return self._executor


def _default_backend() -> SigningBackend:
    return IamSigningBackend(settings.gcp_project_id, settings.gcs_signing_service_account)


_url_signer = GcsUrlSigner(_default_backend)


def url_signer() -> GcsUrlSigner:
    return _url_signer


def warm_up_url_signer() -> None:
    """Lifespan hook: build the backend and fetch its first token."""
    backend = _url_signer.backend()
    warm = getattr(backend, "warm", None)
    if callable(warm):
        warm()


def mint_signed_read_url(bucket: str, object_name: str) -> str:
    return _url_signer.read_url(bucket, object_name)


def mint_signed_read_urls(refs: Sequence[ObjectRef]) -> list[str]:
    return _url_signer.read_urls(refs)


def mint_user_avatar_upload_url(
    firebase_uid: str,
    content_type: str = "image/jpeg",
    byte_length: int = 0,
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    """V4 signed PUT for a user profile avatar in the display bucket."""
    if content_type not in settings.display_allowed_content_types:
        raise InvalidInputError(ErrorCode.UNSUPPORTED_MEDIA_TYPE, f"Unsupported content type: {content_type}")
    if byte_length <= 0 or byte_length > max_bytes:
        raise InvalidInputError(ErrorCode.FILE_TOO_LARGE, "Display asset exceeds maximum size.")

    ext = "webp" if content_type == "image/webp" else "jpg"
    object_name = f"{user_avatar_prefix(firebase_uid)}{uuid.uuid4().hex}.{ext}"
    return _sign_put(object_name, content_type, max_bytes)


def mint_baby_avatar_upload_url(
    baby_profile_id: UUID,
    content_type: str = "image/jpeg",
    byte_length: int = 0,
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    """V4 signed PUT for a baby profile avatar in the display bucket."""
    if content_type not in settings.display_allowed_content_types:
        raise InvalidInputError(ErrorCode.UNSUPPORTED_MEDIA_TYPE, f"Unsupported content type: {content_type}")
    if byte_length <= 0 or byte_length > max_bytes:
        raise InvalidInputError(ErrorCode.FILE_TOO_LARGE, "Display asset exceeds maximum size.")

    ext = "webp" if content_type == "image/webp" else "jpg"
    object_name = f"{baby_avatar_prefix(baby_profile_id)}{uuid.uuid4().hex}.{ext}"
    return _sign_put(object_name, content_type, max_bytes)


def mint_display_upload_for_object(
    object_name: str,
    content_type: str = "image/jpeg",
    max_bytes: int = 2_097_152,
) -> dict[str, str | int]:
    if content_type not in settings.display_allowed_content_types:
        raise InvalidInputError(ErrorCode.UNSUPPORTED_MEDIA_TYPE, f"Unsupported content type: {content_type}")
    if not object_name.startswith("display/"):
        raise ValueError("Upload path must be under display/")
    return _sign_put(object_name, content_type, max_bytes)


def _sign_put(
    object_name: str,
    content_type: str,
    max_bytes: int,
) -> dict[str, str | int]:
    length_range = f"0,{max_bytes}"
    url = _url_signer.upload_url(
        settings.display_bucket,
        object_name,
        content_type=content_type,
        headers={"x-goog-content-length-range": length_range},
    )
    return {
        "upload_url": url,
        "object_path": object_name,
        "bucket": settings.display_bucket,
        "content_type": content_type,
        "max_bytes": max_bytes,
        "expires_in_seconds": int(UPLOAD_URL_TTL.total_seconds()),
        "required_headers": {
            "Content-Type": content_type,
            "x-goog-content-length-range": length_range,
        },
    }


def delete_photo_objects_best_effort(
    *,
    display_path: str | None,
    thumb_path: str | None,
) -> None:
    """Remove display/thumb objects after the SQL row is gone. Failures are
    logged, never raised: the row is already deleted and the request succeeded."""
    objects: list[ObjectRef] = []
    if display_path:
        objects.append((settings.display_bucket, display_path))
    if thumb_path:
        objects.append((settings.thumbnails_bucket, thumb_path))
    if not objects:
        return
    try:
        from google.api_core.exceptions import NotFound
        from google.cloud import storage

        client = storage.Client(project=settings.gcp_project_id)
    except Exception:
        logger.warning("photo_object_delete_client_unavailable", exc_info=True)
        return
    for bucket, object_name in objects:
        try:
            client.bucket(bucket).blob(object_name).delete()
        except NotFound:
            continue  # already gone
        except Exception:
            logger.warning(
                "photo_object_delete_failed bucket=%s name=%s",
                bucket,
                object_name,
                exc_info=True,
            )
