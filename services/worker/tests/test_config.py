import pytest

from lanonna_worker.config import Settings, validate_worker_settings


def test_validate_worker_settings_allows_dev_defaults():
    validate_worker_settings(
        Settings(environment="dev"),
    )


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
