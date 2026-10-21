"""CI guard: tracked files must not contain non-allowlisted email domains."""

import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[3]
_VERIFY = _REPO / "scripts" / "verify-no-personal-emails.sh"


def test_tracked_files_have_no_personal_email_domains():
    result = subprocess.run(
        ["bash", str(_VERIFY)],
        check=False,
        capture_output=True,
        text=True,
        cwd=_REPO,
    )
    assert result.returncode == 0, result.stderr or result.stdout
