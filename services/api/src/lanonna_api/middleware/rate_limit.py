from __future__ import annotations

import time
from collections import defaultdict, deque
from threading import Lock

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

# Per-IP sliding window for sensitive routes (invite batch + photo init).
_LIMITED_PREFIXES = (
    "/v1/photos/init",
    "/v1/babies/",
)
_LIMITED_SUFFIX = "/invitations/batch"
_MAX_REQUESTS = 30
_WINDOW_SECONDS = 60.0

_buckets: dict[str, deque[float]] = defaultdict(deque)
_lock = Lock()


def _client_key(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"


def _is_rate_limited_path(path: str) -> bool:
    if path == "/v1/photos/init":
        return True
    if path.startswith(_LIMITED_PREFIXES[1]) and path.endswith(_LIMITED_SUFFIX):
        return True
    return False


def _allow(key: str) -> bool:
    now = time.monotonic()
    with _lock:
        bucket = _buckets[key]
        while bucket and now - bucket[0] > _WINDOW_SECONDS:
            bucket.popleft()
        if len(bucket) >= _MAX_REQUESTS:
            return False
        bucket.append(now)
        return True


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if request.method in ("POST", "PUT", "PATCH") and _is_rate_limited_path(
            request.url.path
        ):
            bucket_key = f"{_client_key(request)}:{request.url.path}"
            if not _allow(bucket_key):
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many requests. Try again shortly."},
                )
        return await call_next(request)
