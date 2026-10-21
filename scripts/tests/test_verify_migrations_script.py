"""Smoke tests for scripts/verify-migrations.sh."""

import os
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[2]
_SCRIPT = _REPO / "scripts" / "verify-migrations.sh"


def test_verify_migrations_script_exists_and_is_executable():
    assert _SCRIPT.is_file()
    assert os.access(_SCRIPT, os.X_OK)


def test_verify_migrations_skips_without_password():
    result = subprocess.run(
        ["bash", str(_SCRIPT)],
        check=False,
        capture_output=True,
        text=True,
        cwd=_REPO,
        env={k: v for k, v in os.environ.items() if k not in ("PGPASSWORD", "DB_PASSWORD")},
    )
    assert result.returncode == 0
    assert "SKIP" in result.stdout
    assert "lanonna-dev" in result.stdout


def test_old_verify_dev_migrations_script_removed():
    assert not (_REPO / "scripts" / "verify-dev-migrations.sh").exists()
