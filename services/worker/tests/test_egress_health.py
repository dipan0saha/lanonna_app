"""Instance egress health behind the Cloud Run liveness probe (#428)."""

from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_worker.egress_health import EgressHealth
from lanonna_worker.main import app


class _Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def _health(clock: _Clock) -> EgressHealth:
    return EgressHealth("mailjet", failure_threshold=5, unhealthy_after_seconds=120, clock=clock)


def test_healthy_until_failures_are_both_repeated_and_sustained():
    clock = _Clock()
    health = _health(clock)
    assert health.unhealthy_reason() is None

    for _ in range(5):
        health.record_connect_failure()
    # Five fast failures are a blip, not a broken instance.
    assert health.unhealthy_reason() is None

    clock.now += 119
    assert health.unhealthy_reason() is None
    clock.now += 1
    reason = health.unhealthy_reason()
    assert reason is not None
    assert "destination=mailjet" in reason
    assert "consecutive_connect_failures=5" in reason


def test_sustained_but_sparse_failures_stay_healthy():
    clock = _Clock()
    health = _health(clock)
    for _ in range(4):
        health.record_connect_failure()
        clock.now += 300
    assert health.unhealthy_reason() is None


def test_any_successful_connection_resets_the_streak():
    clock = _Clock()
    health = _health(clock)
    for _ in range(5):
        health.record_connect_failure()
    clock.now += 600
    health.record_reachable()
    assert health.unhealthy_reason() is None
    health.record_connect_failure()
    clock.now += 600
    assert health.unhealthy_reason() is None


def test_liveness_endpoint_is_ok_while_healthy():
    with patch("lanonna_worker.main.mailjet_egress") as egress:
        egress.unhealthy_reason.return_value = None
        resp = TestClient(app).get("/health/live")
    assert resp.status_code == 200


def test_liveness_endpoint_fails_when_egress_is_broken(caplog):
    with patch("lanonna_worker.main.mailjet_egress") as egress:
        egress.unhealthy_reason.return_value = "destination=mailjet consecutive_connect_failures=7"
        resp = TestClient(app).get("/health/live")
    assert resp.status_code == 503
    assert "egress_unhealthy destination=mailjet" in caplog.text
