"""scripts/setup-schedulers.sh upserts the worker scheduler jobs with the live dev config."""

import os
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[3]
_SCRIPT = _REPO / "scripts" / "setup-schedulers.sh"


def _run(tmp_path: Path, *, existing: bool, **extra_env: str) -> tuple[subprocess.CompletedProcess, list[str]]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "gcloud.log"
    describe_exit = 0 if existing else 1
    stub = bin_dir / "gcloud"
    stub.write_text(
        "#!/bin/sh\n"
        f'printf "%s\\n" "$*" >> "{log}"\n'
        f'case "$*" in *"jobs describe"*) exit {describe_exit} ;; esac\n'
        "exit 0\n",
        encoding="utf-8",
    )
    stub.chmod(0o755)
    env = {k: v for k, v in os.environ.items() if k not in ("ENVIRONMENT", "GCP_PROJECT_ID")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"
    env.update(extra_env)
    result = subprocess.run(["bash", str(_SCRIPT)], check=False, capture_output=True, text=True, env=env)
    lines = log.read_text(encoding="utf-8").splitlines() if log.exists() else []
    return result, lines


def test_updates_existing_jobs_with_dev_config(tmp_path: Path):
    result, lines = _run(tmp_path, existing=True)
    assert result.returncode == 0, result.stderr
    updates = [line for line in lines if "jobs update pubsub" in line]
    assert len(updates) == 4
    weekly, expire, sweep, event_covers = updates
    assert "weekly-notification-digest" in weekly
    assert "--schedule=0 14 * * 0" in weekly
    assert '--message-body={"type":"weekly_notification_digest"}' in weekly
    assert weekly.endswith("--description=Weekly in-app notification digest push for digest=weekly users")
    assert "expire-pending-invitations" in expire
    assert "--schedule=0 6 * * *" in expire
    assert '--message-body={"type":"expire_pending_invitations"}' in expire
    assert expire.endswith("--description=Mark pending invitations past expires_at as expired")
    assert "sweep-storage-cleanup-jobs" in sweep
    assert "--schedule=*/15 * * * *" in sweep
    assert '--message-body={"type":"sweep_storage_cleanup_jobs"}' in sweep
    assert "purge-stale-event-covers" in event_covers
    assert "--schedule=0 4 * * *" in event_covers
    assert '--message-body={"type":"purge_stale_event_covers"}' in event_covers
    for line in updates:
        assert "--project=lanonna-dev" in line
        assert "--time-zone=UTC" in line
        assert "--topic=lanonna-async-commands" in line
    assert not any(line.startswith("config set") for line in lines)


def test_creates_missing_jobs(tmp_path: Path):
    result, lines = _run(tmp_path, existing=False)
    assert result.returncode == 0, result.stderr
    assert len([line for line in lines if "jobs create pubsub" in line]) == 4


def test_unknown_project_fails_before_gcloud(tmp_path: Path):
    result, lines = _run(tmp_path, existing=True, GCP_PROJECT_ID="someone-else")
    assert result.returncode != 0
    assert lines == []
