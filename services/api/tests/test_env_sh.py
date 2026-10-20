"""Unit tests for scripts/lib/env.sh resolution helpers."""

import os
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[3]
_ENV_SH = _REPO / "scripts" / "lib" / "env.sh"


def _bash_snippet(script: str, **env: str) -> subprocess.CompletedProcess[str]:
    merged = {k: v for k, v in os.environ.items() if k not in ("GCP_PROJECT_ID", "ENVIRONMENT")}
    merged.update(env)
    return subprocess.run(
        ["bash", "-c", script],
        check=False,
        capture_output=True,
        text=True,
        env=merged,
        cwd=_REPO,
    )


def test_default_project_is_lanonna_dev():
    result = _bash_snippet(
        f'source "{_ENV_SH}" && lanonna_resolve_gcp_project_id && echo "$GCP_PROJECT_ID"'
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "lanonna-dev"


def test_lanonna_prod_maps_to_prod_environment():
    result = _bash_snippet(
        f'source "{_ENV_SH}" && GCP_PROJECT_ID=lanonna-prod lanonna_resolve_environment && echo "$ENVIRONMENT"'
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "prod"


def test_unknown_project_requires_explicit_environment():
    result = _bash_snippet(
        f'source "{_ENV_SH}" && GCP_PROJECT_ID=my-other-project lanonna_resolve_environment'
    )
    assert result.returncode != 0
    assert "Unknown GCP_PROJECT_ID" in result.stderr


def test_placeholder_values_detected():
    result = _bash_snippet(
        f'source "{_ENV_SH}" && lanonna_reject_placeholder TEST __SET_PROD_MAILJET_FROM_EMAIL__'
    )
    assert result.returncode != 0
    assert "placeholder" in result.stderr.lower()


def test_infra_env_path_for_dev_api():
    result = _bash_snippet(
        f'source "{_ENV_SH}" && lanonna_infra_env_file api'
    )
    assert result.returncode == 0
    assert result.stdout.strip().endswith("infra/env/dev.api.env")
