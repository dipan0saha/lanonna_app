"""Monotonic Android versionCode derivation (issue #444)."""

import os
import shutil
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[2]
_MOBILE = _REPO / "apps" / "mobile"
_DERIVE = _MOBILE / "scripts" / "derive_android_version_code.sh"
_BUILD_STAMP = _MOBILE / "scripts" / "build_stamp.sh"
_EPOCH = 1_577_836_800
_FLOOR = 300


def _run_git(repo: Path, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        capture_output=True,
        text=True,
        env=merged,
    )


def _derive(repo: Path, env: dict | None = None) -> subprocess.CompletedProcess:
    merged = {k: v for k, v in os.environ.items() if k != "BUILD_NUMBER"}
    if env:
        merged.update(env)
    return subprocess.run(
        ["bash", str(_DERIVE), str(repo)],
        check=False,
        capture_output=True,
        text=True,
        env=merged,
    )


def _build_stamp(repo_root: Path, require: bool = False) -> subprocess.CompletedProcess:
    scripts = repo_root / "apps" / "mobile" / "scripts"
    env = {k: v for k, v in os.environ.items() if k not in ("BUILD_NUMBER", "REQUIRE_BUILD_STAMP")}
    if require:
        env["REQUIRE_BUILD_STAMP"] = "1"
    return subprocess.run(
        ["bash", str(scripts / "build_stamp.sh")],
        check=False,
        capture_output=True,
        text=True,
        env=env,
        cwd=repo_root / "apps" / "mobile",
    )


def _legacy_rev_list_count(repo: Path) -> int:
    out = _run_git(repo, "rev-list", "--count", "HEAD")
    assert out.returncode == 0, out.stderr
    return int(out.stdout.strip())


def _commit_at(repo: Path, when: str, message: str) -> None:
    env = {
        "GIT_AUTHOR_DATE": when,
        "GIT_COMMITTER_DATE": when,
    }
    marker = repo / f".commit-{message.replace(' ', '-')}"
    marker.write_text(when)
    result = _run_git(repo, "add", ".")
    assert result.returncode == 0, result.stderr
    result = _run_git(repo, "commit", "-m", message, env=env)
    assert result.returncode == 0, result.stderr


def _init_stamp_repo(tmp_path: Path) -> Path:
    root = tmp_path / "mini"
    root.mkdir()
    (root / "apps" / "mobile" / "scripts").mkdir(parents=True)
    for name in ("derive_android_version_code.sh", "build_stamp.sh"):
        shutil.copy2(_MOBILE / "scripts" / name, root / "apps" / "mobile" / "scripts" / name)
    _run_git(root, "init", "-b", "main")
    _run_git(root, "config", "user.email", "noreply@users.noreply.github.com")
    _run_git(root, "config", "user.name", "test")
    return root


def test_squash_merge_rev_list_regresses_but_version_code_does_not(tmp_path):
    root = _init_stamp_repo(tmp_path)
    _commit_at(root, "2026-10-24T10:00:00Z", "main-1")
    _commit_at(root, "2026-10-24T10:01:00Z", "main-2")
    _run_git(root, "checkout", "-b", "feature")
    _commit_at(root, "2026-10-24T10:02:00Z", "feature-1")
    _commit_at(root, "2026-10-24T10:03:00Z", "feature-2")

    branch_count = _legacy_rev_list_count(root)
    branch_code = int(_derive(root).stdout.strip())

    _run_git(root, "checkout", "main")
    squash = _run_git(root, "merge", "--squash", "feature")
    assert squash.returncode == 0, squash.stderr
    _commit_at(root, "2026-10-24T10:04:00Z", "squashed-feature")

    main_count = _legacy_rev_list_count(root)
    main_code = int(_derive(root).stdout.strip())

    assert main_count < branch_count, "squash merge lowered rev-list count (old derivation would regress)"
    assert main_code >= branch_code


def test_monotonic_across_sequential_commits(tmp_path):
    root = _init_stamp_repo(tmp_path)
    codes: list[int] = []
    for minute in range(3):
        _commit_at(root, f"2026-10-24T11:{minute:02d}:00Z", f"c{minute}")
        codes.append(int(_derive(root).stdout.strip()))
    assert codes == sorted(codes)
    assert len(set(codes)) == len(codes)


def test_prod_build_stamp_fails_without_git(tmp_path):
    nogit = tmp_path / "nogit"
    nogit.mkdir()
    scripts = nogit / "apps" / "mobile" / "scripts"
    scripts.mkdir(parents=True)
    for name in ("derive_android_version_code.sh", "build_stamp.sh"):
        shutil.copy2(_MOBILE / "scripts" / name, scripts / name)
    result = _build_stamp(nogit, require=True)
    assert result.returncode != 0
    assert "BUILD_GIT_SHA is required" in result.stderr or "BUILD_NUMBER is required" in result.stderr


def test_explicit_build_number_override(tmp_path):
    root = _init_stamp_repo(tmp_path)
    _commit_at(root, "2026-10-24T12:00:00Z", "only")
    result = _derive(root, env={"BUILD_NUMBER": "9999"})
    assert result.returncode == 0
    assert result.stdout.strip() == "9999"


def test_repo_matches_head_committer_scheme():
    ts = int(
        subprocess.run(
            ["git", "-C", str(_REPO), "log", "-1", "--format=%ct", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    )
    expected = max(_FLOOR, ts - _EPOCH)
    result = _derive(_REPO)
    assert result.returncode == 0, result.stderr
    assert int(result.stdout.strip()) == expected
