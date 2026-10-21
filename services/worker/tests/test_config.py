import os
import subprocess
from pathlib import Path

import pytest

from lanonna_worker.config import (
    Settings,
    invite_link_base_error,
    validate_worker_settings,
)

_DEPLOY = Path(__file__).resolve().parents[1] / "scripts" / "deploy.sh"
_WORKER_ENV = Path(__file__).resolve().parents[3] / "infra" / "env" / "dev.worker.env"
_WORKER_LOCAL_EXAMPLE = (
    Path(__file__).resolve().parents[3] / "infra" / "env" / "dev.worker.local.env.example"
)


def test_validate_worker_settings_allows_dev_defaults():
    validate_worker_settings(
        Settings(environment="dev", mailjet_from_email="sender@example.com"),
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
    text = _DEPLOY.read_text()
    assert "MAILJET_FROM_EMAIL:-hello@lanonna.app" not in text
    assert "hello@lanonna.app" in text
    assert 'source "${WORKER_ENV_FILE}"' not in text
    assert "lanonna_infra_env_local_file" in text
    # Sender check is before Cloud Build.
    assert text.index("require_mailjet_sender") < text.index("gcloud builds submit")
    worker_env = _WORKER_ENV.read_text()
    assert "MAILJET_FROM_EMAIL=" not in worker_env
    assert _WORKER_LOCAL_EXAMPLE.is_file()
    assert "MAILJET_FROM_EMAIL=" in _WORKER_LOCAL_EXAMPLE.read_text()


def test_dev_worker_env_sources_as_shell():
    """Plain `source` must succeed; an unquoted display name exits 127 (#43)."""
    result = subprocess.run(
        [
            "bash",
            "-c",
            'set -a; source "$1"; set +a; printf "%s" "$MAILJET_FROM_NAME"',
            "bash",
            str(_WORKER_ENV),
        ],
        check=False,
        capture_output=True,
        text=True,
        env={"PATH": os.environ.get("PATH", "")},
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == "La Nonna"
    assert "command not found" not in result.stderr


def test_env_loader_reads_spaces_and_does_not_execute(tmp_path: Path):
    marker = tmp_path / "executed"
    env_file = tmp_path / "worker.env"
    env_file.write_text(
        "MAILJET_FROM_EMAIL=sender@example.com\n"
        "MAILJET_FROM_NAME=La Nonna\n"
        f"PWNED=$(touch {marker})\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [
            "bash",
            "-c",
            """
            unset MAILJET_FROM_EMAIL MAILJET_FROM_NAME PWNED
            source "$1"
            require_mailjet_sender "$2" "$3"
            printf '%s\\n%s' "$MAILJET_FROM_NAME" "$PWNED"
            """,
            "bash",
            str(_DEPLOY),
            str(env_file),
            str(tmp_path / "missing.local.env"),
        ],
        check=False,
        capture_output=True,
        text=True,
        env={"PATH": os.environ.get("PATH", "")},
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == f"La Nonna\n$(touch {marker})"
    assert not marker.exists()


def test_require_mailjet_sender_loads_local_override(tmp_path: Path):
    base = tmp_path / "dev.worker.env"
    base.write_text('MAILJET_FROM_NAME="La Nonna"\n', encoding="utf-8")
    local = tmp_path / "dev.worker.local.env"
    local.write_text("MAILJET_FROM_EMAIL=sender@example.com\n", encoding="utf-8")
    result = subprocess.run(
        [
            "bash",
            "-c",
            """
            unset MAILJET_FROM_EMAIL MAILJET_FROM_NAME
            source "$1"
            require_mailjet_sender "$2" "$3"
            printf '%s' "$MAILJET_FROM_EMAIL"
            """,
            "bash",
            str(_DEPLOY),
            str(base),
            str(local),
        ],
        check=False,
        capture_output=True,
        text=True,
        env={"PATH": os.environ.get("PATH", "")},
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == "sender@example.com"


def _gcloud_stub(tmp_path: Path) -> tuple[Path, dict[str, str]]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "gcloud.log"
    stub = bin_dir / "gcloud"
    stub.write_text(
        "#!/bin/sh\n"
        f'printf "%s\\n" "$*" >> "{log}"\n'
        "exit 1\n",
        encoding="utf-8",
    )
    stub.chmod(0o755)
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"
    env.pop("MAILJET_FROM_EMAIL", None)
    env.pop("MAILJET_FROM_NAME", None)
    return log, env


def test_deploy_rejects_unvalidated_sender_before_gcloud(tmp_path: Path):
    log, env = _gcloud_stub(tmp_path)
    env["MAILJET_FROM_EMAIL"] = "hello@lanonna.app"
    result = subprocess.run(
        ["bash", str(_DEPLOY)],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode != 0
    assert "not a validated Mailjet sender" in result.stderr
    assert not log.exists()


def test_deploy_fails_without_sender_before_gcloud(tmp_path: Path):
    log, env = _gcloud_stub(tmp_path)
    env["WORKER_ENV_FILE"] = str(tmp_path / "missing.env")
    env["WORKER_LOCAL_ENV_FILE"] = str(tmp_path / "missing.local.env")
    result = subprocess.run(
        ["bash", str(_DEPLOY)],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode != 0
    assert "MAILJET_FROM_EMAIL is required" in result.stderr
    assert not log.exists()


def test_plain_deploy_loads_spaced_name_before_build(tmp_path: Path):
    log, env = _gcloud_stub(tmp_path)
    local = tmp_path / "dev.worker.local.env"
    local.write_text("MAILJET_FROM_EMAIL=sender@example.com\n", encoding="utf-8")
    env["WORKER_LOCAL_ENV_FILE"] = str(local)
    env["WORKER_ENV_FILE"] = str(_WORKER_ENV)
    result = subprocess.run(
        ["bash", str(_DEPLOY)],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )
    assert "command not found" not in result.stderr
    assert result.returncode != 0
    recorded = log.read_text(encoding="utf-8")
    assert recorded.startswith("config set project")


def test_invite_link_base_rejects_custom_scheme_and_dev_host_outside_dev():
    assert invite_link_base_error("lanonna://app", environment="dev") is not None
    assert (
        invite_link_base_error(
            "https://lanonna-dev.firebaseapp.com", environment="prod"
        )
        is not None
    )
    assert (
        invite_link_base_error(
            "https://lanonna-prod.firebaseapp.com", environment="prod"
        )
        is None
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
