"""CI guard: tracked files must not contain personal or non-role email addresses."""

import os
import subprocess
from pathlib import Path

import pytest

_REPO = Path(__file__).resolve().parents[3]
_VERIFY = _REPO / "scripts" / "verify-no-personal-emails.sh"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ, LANONNA_EMAIL_GUARD_ROOT=str(root))
    return subprocess.run(
        ["bash", str(_VERIFY)], check=False, capture_output=True, text=True, env=env
    )


def _materialize(content: bytes) -> bytes:
    # Fixtures avoid literal addresses so this tracked file passes the guard.
    return content.replace(b"[at]", b"@").replace(b"[pct]", b"%40").replace(b"[ent]", b"&#64;")


def _repo_with(tmp_path: Path, name: str, content: bytes) -> Path:
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    target = tmp_path / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(_materialize(content))
    subprocess.run(["git", "-C", str(tmp_path), "add", "-A"], check=True)
    return tmp_path


def test_tracked_files_have_no_personal_email_domains():
    result = _run(_REPO)
    assert result.returncode == 0, result.stderr or result.stdout


@pytest.mark.parametrize(
    ("name", "content"),
    [
        ("a.md", b"contact zq.person1[at]gmail.com"),
        ("b.yaml", b"from: zqperson2[at]GMAIL.COM"),
        ("c.json", b'{"e": "zqperson3[at]yahoo.co.uk"}'),
        ("d.arb", b'{"k": "zqperson4[at]hotmail.fr"}'),
        ("e.py", b"x = 'zqperson5[at]outlook.com'"),
        ("f.txt", b"zqperson6[at]icloud.com"),
        ("g.sh", b"DIR=$HOME/GoogleDrive-zqperson7[pct]gmail.com/x"),
        ("h.html", b"zqperson8[ent]proton.me"),
        ("i.env", b"QA=zqperson9[at]mail.grokbot.com"),
        ("j.md", b"owner zqperson10[at]lanonna.app"),
        ("k.png", b"\x89PNG\r\n\x1a\n\x00tEXtAuthor\x00zqperson11[at]gmail.com\x00\xff\xfe"),
        ("l.dart", b"final e = 'zqperson12[at]me.com';"),
    ],
)
def test_guard_flags_personal_addresses_without_printing_them(tmp_path, name, content):
    result = _run(_repo_with(tmp_path, name, content))
    assert result.returncode == 1, result.stdout
    assert name in result.stderr
    assert "zqperson" not in result.stderr + result.stdout


@pytest.mark.parametrize(
    "content",
    [
        b"hello@lanonna.app",
        b"${MAILJET_FROM_EMAIL:-hello@lanonna.app}",
        b"support@lanonna.app noreply@lanonna.app",
        b"user@example.com a@test.com x@example.test",
        b"logo@2x.png icon@3x.webp",
        b"lanonna-api@lanonna-dev.iam.gserviceaccount.com",
        b"use outlook or gmail, not live chat",
        b"fan@livestream.com someone@mylive.com",
        b"npm i pkg@1.2.3 and @gmail.com alone",
    ],
)
def test_guard_allows_placeholders_and_role_addresses(tmp_path, content):
    result = _run(_repo_with(tmp_path, "ok.txt", content))
    assert result.returncode == 0, result.stderr
