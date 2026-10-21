"""scripts/deploy-invite-hosting.sh must succeed without Hosting Run IAM grants."""

import os
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[3]
_SCRIPT = _REPO / "scripts" / "deploy-invite-hosting.sh"


def test_hosting_deploy_skips_firebase_hosting_run_iam(tmp_path: Path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    gcloud_log = tmp_path / "gcloud.log"
    firebase_log = tmp_path / "firebase.log"

    gcloud = bin_dir / "gcloud"
    gcloud.write_text(
        f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{gcloud_log}"\nexit 0\n',
        encoding="utf-8",
    )
    gcloud.chmod(0o755)

    firebase = bin_dir / "firebase"
    firebase.write_text(
        f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{firebase_log}"\nexit 0\n',
        encoding="utf-8",
    )
    firebase.chmod(0o755)

    env = {k: v for k, v in os.environ.items() if k not in ("GCP_PROJECT_ID", "ENVIRONMENT")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"
    env["ANDROID_SHA256"] = "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"

    result = subprocess.run(
        ["bash", str(_SCRIPT)],
        check=False,
        capture_output=True,
        text=True,
        env=env,
        cwd=_REPO,
    )
    assert result.returncode == 0, result.stderr
    gcloud_text = gcloud_log.read_text(encoding="utf-8")
    assert "add-iam-policy-binding" not in gcloud_text
    assert "firebasehosting" not in gcloud_text or "enable" in gcloud_text
    assert "deploy --only hosting" in firebase_log.read_text(encoding="utf-8")
