from pathlib import Path

import pytest

from lanonna_worker.config import Settings, validate_worker_settings


def test_validate_worker_settings_allows_dev_defaults():
    validate_worker_settings(
        Settings(environment="dev", mailjet_from_email="lanonnaapp@gmail.com"),
    )


def test_validate_worker_settings_rejects_missing_sender():
    with pytest.raises(RuntimeError, match="MAILJET_FROM_EMAIL is required"):
        validate_worker_settings(
            Settings(environment="dev", mailjet_from_email=""),
        )


def test_validate_worker_settings_rejects_unvalidated_sender():
    with pytest.raises(RuntimeError, match="hello@lanonna.app"):
        validate_worker_settings(
            Settings(
                environment="dev",
                mailjet_from_email="Hello@Lanonna.app",
            ),
        )


def test_deploy_script_has_no_unvalidated_sender_fallback():
    deploy = Path(__file__).resolve().parents[1] / "scripts" / "deploy.sh"
    text = deploy.read_text()
    assert "MAILJET_FROM_EMAIL:-hello@lanonna.app" not in text
    assert "hello@lanonna.app" in text
    env_file = (
        Path(__file__).resolve().parents[3] / "infra" / "env" / "dev.worker.env"
    )
    assert "MAILJET_FROM_EMAIL=lanonnaapp@gmail.com" in env_file.read_text()


def test_validate_worker_settings_rejects_dev_project_outside_dev():
    with pytest.raises(RuntimeError, match="GCP_PROJECT_ID"):
        validate_worker_settings(
            Settings(
                environment="prod",
                gcp_project_id="lanonna-dev",
                display_bucket="lanonna-prod-display",
                thumbnails_bucket="lanonna-prod-thumbnails",
            ),
        )
