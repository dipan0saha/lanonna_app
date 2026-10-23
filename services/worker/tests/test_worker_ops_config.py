"""Static checks that the #428 safeguards stay wired into deploy and monitoring."""

from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def test_deploy_sets_http_liveness_probe_on_health_live():
    deploy = (REPO / "services/worker/scripts/deploy.sh").read_text()
    assert "--liveness-probe=httpGet.path=/health/live" in deploy


def test_monitoring_alerts_on_worker_mailjet_send_failures():
    tf = (REPO / "infra/terraform/modules/platform/monitoring.tf").read_text()
    assert 'resource "google_logging_metric" "worker_mailjet_send_failed"' in tf
    assert 'textPayload:"mailjet_send_failed"' in tf
    assert 'resource "google_monitoring_alert_policy" "worker_mailjet_send_failed"' in tf
