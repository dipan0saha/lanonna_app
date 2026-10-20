"""services/api/scripts/deploy.sh reads per-environment Cloud Run settings."""

import os
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[3]
_DEPLOY = _REPO / "services" / "api" / "scripts" / "deploy.sh"
_DEV_API_ENV = _REPO / "infra" / "env" / "dev.api.env"


def _run_deploy(tmp_path: Path, **extra_env: str) -> tuple[subprocess.CompletedProcess, str]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "gcloud.log"
    stub = bin_dir / "gcloud"
    stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{log}"\nexit 0\n', encoding="utf-8")
    stub.chmod(0o755)
    env = {k: v for k, v in os.environ.items() if not k.startswith("API_")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"
    env["USE_LOCAL_DOCKER"] = "0"
    env.update(extra_env)
    result = subprocess.run(
        ["bash", str(_DEPLOY)], check=False, capture_output=True, text=True, env=env
    )
    return result, log.read_text(encoding="utf-8") if log.exists() else ""


def _deploy_line(log: str) -> str:
    return next(line for line in log.splitlines() if line.startswith("run deploy api"))


def test_dev_env_file_keeps_one_warm_instance(tmp_path: Path):
    result, log = _run_deploy(tmp_path)
    assert result.returncode == 0, result.stderr
    line = _deploy_line(log)
    assert "--min-instances=1" in line
    assert "--max-instances=10" in line


def test_shell_value_overrides_env_file(tmp_path: Path):
    result, log = _run_deploy(tmp_path, API_MIN_INSTANCES="0")
    assert result.returncode == 0, result.stderr
    assert "--min-instances=0" in _deploy_line(log)


def test_without_env_file_defaults_to_scale_to_zero(tmp_path: Path):
    result, log = _run_deploy(tmp_path, API_ENV_FILE=str(tmp_path / "missing.env"))
    assert result.returncode == 0, result.stderr
    line = _deploy_line(log)
    assert "--min-instances=0" in line
    assert "--max-instances=10" in line


def test_rejects_min_above_max_before_gcloud(tmp_path: Path):
    result, log = _run_deploy(tmp_path, API_MIN_INSTANCES="11")
    assert result.returncode != 0
    assert "min <= max" in result.stderr
    assert log == ""


def test_env_file_is_parsed_not_executed(tmp_path: Path):
    marker = tmp_path / "executed"
    env_file = tmp_path / "api.env"
    env_file.write_text(f"API_MIN_INSTANCES=2\nPWNED=$(touch {marker})\n", encoding="utf-8")
    result, log = _run_deploy(tmp_path, API_ENV_FILE=str(env_file))
    assert result.returncode == 0, result.stderr
    assert "--min-instances=2" in _deploy_line(log)
    assert not marker.exists()


def test_dev_api_env_sets_min_instances():
    assert "API_MIN_INSTANCES=1" in _DEV_API_ENV.read_text(encoding="utf-8")


def test_deploy_sets_environment_dev_by_default(tmp_path: Path):
    result, log = _run_deploy(tmp_path)
    assert result.returncode == 0, result.stderr
    line = _deploy_line(log)
    assert "ENVIRONMENT=dev," in line.replace(" ", "")


def test_deploy_uses_prod_env_when_project_is_prod(tmp_path: Path):
    result, log = _run_deploy(tmp_path, GCP_PROJECT_ID="lanonna-prod")
    assert result.returncode == 0, result.stderr
    line = _deploy_line(log)
    assert "ENVIRONMENT=prod," in line.replace(" ", "")
    assert "--min-instances=1" in line
    assert "APP_CHECK_ENFORCE=true" in line
