"""Per-instance outbound (egress) health, reported to the Cloud Run liveness probe (#428).

A worker instance can lose its outbound path to one destination while its own
ingress and Google-internal traffic (Pub/Sub push, Cloud SQL, GCS) keep working.
On dev, one instance had every Mailjet TCP/TLS handshake reset for almost two hours
while fresh instances running the same image sent fine. Nothing restarted it: it kept
answering requests and the startup probe only checks the port.

``send_messages`` records the outcome of each Mailjet connection here. When
connections keep failing at the connect stage for a sustained window, with no
successful connection in between, ``/health/live`` returns 503. Cloud Run then
replaces the instance, and Pub/Sub redelivers the unacked invites to the new one.

Only connect-stage failures count: an HTTP response of any status means the network
path works, so it resets the streak.
"""

from __future__ import annotations

import threading
import time
from collections.abc import Callable

# Five connect failures in a row, with the first one at least two minutes old.
# Pub/Sub backoff spaces redeliveries out, so a brief network blip doesn't trip this.
CONNECT_FAILURE_THRESHOLD = 5
UNHEALTHY_AFTER_SECONDS = 120.0


class EgressHealth:
    def __init__(
        self,
        destination: str,
        *,
        failure_threshold: int = CONNECT_FAILURE_THRESHOLD,
        unhealthy_after_seconds: float = UNHEALTHY_AFTER_SECONDS,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.destination = destination
        self._failure_threshold = failure_threshold
        self._unhealthy_after_seconds = unhealthy_after_seconds
        self._clock = clock
        self._lock = threading.Lock()
        self._consecutive_failures = 0
        self._first_failure_at: float | None = None

    def record_connect_failure(self) -> None:
        with self._lock:
            self._consecutive_failures += 1
            if self._first_failure_at is None:
                self._first_failure_at = self._clock()

    def record_reachable(self) -> None:
        with self._lock:
            self._consecutive_failures = 0
            self._first_failure_at = None

    def unhealthy_reason(self) -> str | None:
        """Why this instance should be replaced, or None while it is healthy."""
        with self._lock:
            if self._first_failure_at is None:
                return None
            failing_for = self._clock() - self._first_failure_at
            if (
                self._consecutive_failures < self._failure_threshold
                or failing_for < self._unhealthy_after_seconds
            ):
                return None
            return (
                f"destination={self.destination} "
                f"consecutive_connect_failures={self._consecutive_failures} "
                f"failing_for_seconds={int(failing_for)}"
            )

