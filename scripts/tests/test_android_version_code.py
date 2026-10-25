"""Android versionCode derivation and the Play release guard (issue #444)."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

_REPO = Path(__file__).resolve().parents[2]
_MOBILE = _REPO / "apps" / "mobile"
_SCRIPTS = _MOBILE / "scripts"
_EPOCH = 1_577_836_800
_STAMP_SCRIPTS = (
    "derive_android_version_code.sh",
    "build_stamp.sh",
    "android_release_guard.sh",
    "record_android_release.sh",
    "flutter_build_stamp.sh",
    "flutter_build_apk.sh",
    "flutter_build_appbundle.sh",
)
_STRIP_ENV = ("BUILD_NUMBER", "ANDROID_RELEASE_BUILD", "GIT_DIR", "GIT_WORK_TREE")


def _clean_env(extra: dict | None = None) -> dict:
    env = {k: v for k, v in os.environ.items() if k not in _STRIP_ENV}
    env.update(extra or {})
    return env


def _git(repo: Path, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        capture_output=True,
        text=True,
        env=_clean_env(env),
    )


def _ok(result: subprocess.CompletedProcess) -> str:
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def _code_at(when: str) -> int:
    from datetime import datetime

    return int(datetime.fromisoformat(when.replace("Z", "+00:00")).timestamp()) - _EPOCH


def _commit_at(repo: Path, when: str, message: str) -> None:
    (repo / f"{message.replace(' ', '-')}.txt").write_text(when)
    _ok(_git(repo, "add", "."))
    _ok(_git(repo, "commit", "-q", "-m", message, env={"GIT_AUTHOR_DATE": when, "GIT_COMMITTER_DATE": when}))


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A clone of a bare `origin` that carries the stamp scripts, with one commit on main."""
    origin = tmp_path / "origin.git"
    _ok(_git(tmp_path, "init", "-q", "--bare", "-b", "main", str(origin)))
    root = tmp_path / "work"
    _ok(_git(tmp_path, "clone", "-q", str(origin), str(root)))
    _ok(_git(root, "checkout", "-q", "-b", "main"))
    _ok(_git(root, "config", "user.email", "test@example.invalid"))
    _ok(_git(root, "config", "user.name", "test"))
    scripts = root / "apps" / "mobile" / "scripts"
    scripts.mkdir(parents=True)
    for name in _STAMP_SCRIPTS:
        shutil.copy2(_SCRIPTS / name, scripts / name)
    flavors = root / "apps" / "mobile" / "flavors"
    flavors.mkdir()
    (flavors / "dev.json").write_text('{\n  "APP_ENV": "dev"\n}\n')
    (flavors / "prod.json").write_text('{\n  "APP_ENV": "prod"\n}\n')
    _commit_at(root, "2026-10-24T10:00:00Z", "main-1")
    _ok(_git(root, "push", "-q", "origin", "main"))
    return root


def _derive(root: Path, env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(root / "apps/mobile/scripts/derive_android_version_code.sh"), str(root)],
        check=False,
        capture_output=True,
        text=True,
        env=_clean_env(env),
    )


def _stamp(root: Path, release: bool, env: dict | None = None) -> subprocess.CompletedProcess:
    extra = dict(env or {})
    if release:
        extra["ANDROID_RELEASE_BUILD"] = "1"
    return subprocess.run(
        ["bash", str(root / "apps/mobile/scripts/build_stamp.sh")],
        check=False,
        capture_output=True,
        text=True,
        env=_clean_env(extra),
        cwd=root,
    )


def _record(root: Path, code: int) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(root / "apps/mobile/scripts/record_android_release.sh"), str(code)],
        check=False,
        capture_output=True,
        text=True,
        env=_clean_env(),
        cwd=root,
    )


def _wrapper(root: Path, tmp_path: Path, name: str, *args: str, env: dict | None = None):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    fake = bin_dir / "flutter"
    fake.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n')
    fake.chmod(0o755)
    extra = dict(env or {})
    extra["PATH"] = f"{bin_dir}{os.pathsep}{os.environ['PATH']}"
    return subprocess.run(
        ["bash", str(root / "apps/mobile/scripts" / name), *args],
        check=False,
        capture_output=True,
        text=True,
        env=_clean_env(extra),
    )


# --- derivation -------------------------------------------------------------


def test_squash_merge_rev_list_regresses_but_version_code_does_not(repo):
    _commit_at(repo, "2026-10-24T10:01:00Z", "main-2")
    _ok(_git(repo, "checkout", "-q", "-b", "feature"))
    _commit_at(repo, "2026-10-24T10:02:00Z", "feature-1")
    _commit_at(repo, "2026-10-24T10:03:00Z", "feature-2")
    branch_count = int(_ok(_git(repo, "rev-list", "--count", "HEAD")))
    branch_code = int(_ok(_derive(repo)))

    _ok(_git(repo, "checkout", "-q", "main"))
    _ok(_git(repo, "merge", "--squash", "-q", "feature"))
    _commit_at(repo, "2026-10-24T10:04:00Z", "squashed-feature")
    main_count = int(_ok(_git(repo, "rev-list", "--count", "HEAD")))
    main_code = int(_ok(_derive(repo)))

    assert main_count < branch_count, "the old rev-list derivation regresses on a squash merge"
    assert main_code > branch_code


def test_code_is_committer_seconds_since_2020(repo):
    _commit_at(repo, "2026-10-24T11:00:00Z", "c1")
    assert int(_ok(_derive(repo))) == _code_at("2026-10-24T11:00:00Z")


def test_explicit_rev_is_derived_without_checkout(repo):
    first = _ok(_git(repo, "rev-parse", "HEAD"))
    _commit_at(repo, "2026-10-24T11:00:00Z", "c1")
    result = subprocess.run(
        ["bash", str(repo / "apps/mobile/scripts/derive_android_version_code.sh"), str(repo), first],
        check=False, capture_output=True, text=True, env=_clean_env(),
    )
    assert int(_ok(result)) == _code_at("2026-10-24T10:00:00Z")


def test_repo_head_matches_scheme():
    ts = int(_ok(_git(_REPO, "log", "-1", "--format=%ct", "HEAD")))
    result = subprocess.run(
        ["bash", str(_SCRIPTS / "derive_android_version_code.sh"), str(_REPO)],
        check=False, capture_output=True, text=True, env=_clean_env(),
    )
    assert int(_ok(result)) == ts - _EPOCH
    # Far above the legacy rev-list codes (~239-241) already installed on dev devices.
    assert ts - _EPOCH > 200_000_000


def test_explicit_build_number_override(repo):
    assert _ok(_derive(repo, env={"BUILD_NUMBER": "9999"})) == "9999"


@pytest.mark.parametrize("bad", ["abc", "0", "0999", "-5", "12.5", "2100000001", "99999999999"])
def test_invalid_override_fails_loudly_even_for_dev(repo, bad):
    assert _derive(repo, env={"BUILD_NUMBER": bad}).returncode == 1
    stamp = _stamp(repo, release=False, env={"BUILD_NUMBER": bad})
    assert stamp.returncode != 0
    assert "FAIL" in stamp.stderr


def test_commit_before_epoch_fails(repo):
    _commit_at(repo, "2019-12-31T23:59:59Z", "ancient")
    assert _derive(repo).returncode == 1


def test_dev_stamp_without_git_is_unknown(tmp_path):
    scripts = tmp_path / "nogit" / "apps" / "mobile" / "scripts"
    scripts.mkdir(parents=True)
    for name in _STAMP_SCRIPTS:
        shutil.copy2(_SCRIPTS / name, scripts / name)
    env = {"GIT_CEILING_DIRECTORIES": str(tmp_path)}
    dev = _stamp(tmp_path / "nogit", release=False, env=env)
    assert _ok(dev).splitlines() == ["export BUILD_GIT_SHA=unknown", "export BUILD_NUMBER=unknown"]
    rel = _stamp(tmp_path / "nogit", release=True, env=env)
    assert rel.returncode != 0
    assert "BUILD_GIT_SHA is required" in rel.stderr


# --- release guard ----------------------------------------------------------


def test_release_from_clean_main_passes_first_release(repo):
    out = _stamp(repo, release=True)
    assert f"export BUILD_NUMBER={_code_at('2026-10-24T10:00:00Z')}" in _ok(out)
    assert "first release" in out.stderr


def test_release_refuses_dirty_tree(repo):
    (repo / "untracked.txt").write_text("x")
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and "not clean" in out.stderr
    (repo / "untracked.txt").unlink()
    (repo / "main-1.txt").write_text("edited")
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and "not clean" in out.stderr


def test_release_refuses_branch_commit_not_on_origin_main(repo):
    _ok(_git(repo, "checkout", "-q", "-b", "feature"))
    _commit_at(repo, "2026-10-24T10:05:00Z", "feature-1")
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and "not on origin/main" in out.stderr
    # A local main commit that was never pushed is not on origin/main either.
    _ok(_git(repo, "checkout", "-q", "main"))
    _commit_at(repo, "2026-10-24T10:06:00Z", "unpushed")
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and "not on origin/main" in out.stderr


def test_release_refuses_when_origin_unreachable(repo, tmp_path):
    _ok(_git(repo, "remote", "set-url", "origin", str(tmp_path / "missing.git")))
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and "could not fetch origin" in out.stderr


def test_record_then_next_main_commit_passes(repo):
    first = _code_at("2026-10-24T10:00:00Z")
    _ok(_record(repo, first))
    assert f"refs/tags/android-vc-{first}" in _ok(_git(repo, "ls-remote", "--tags", "origin"))
    # Rebuilding the released commit is refused: same code as the release.
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and f"last released code {first}" in out.stderr
    _commit_at(repo, "2026-10-24T12:00:00Z", "main-2")
    _ok(_git(repo, "push", "-q", "origin", "main"))
    assert f"> last released {first}" in _stamp(repo, release=True).stderr


def test_release_catches_committer_time_going_backwards(repo):
    """Clock skew / cherry-pick / rewritten dates: a newer main commit with an older time."""
    _commit_at(repo, "2026-10-24T12:00:00Z", "main-2")
    _ok(_git(repo, "push", "-q", "origin", "main"))
    _ok(_record(repo, _code_at("2026-10-24T12:00:00Z")))
    _commit_at(repo, "2026-10-24T11:00:00Z", "skewed")
    _ok(_git(repo, "push", "-q", "origin", "main"))
    out = _stamp(repo, release=True)
    assert out.returncode != 0 and "not greater than the last released code" in out.stderr


def test_release_same_second_collision_is_refused(repo):
    released = _code_at("2026-10-24T10:00:00Z")
    _ok(_record(repo, released))
    _commit_at(repo, "2026-10-24T10:00:00Z", "same-second")
    _ok(_git(repo, "push", "-q", "origin", "main"))
    assert int(_ok(_derive(repo))) == released
    assert _stamp(repo, release=True).returncode != 0


def test_release_override_must_exceed_last_release(repo):
    released = _code_at("2026-10-24T10:00:00Z")
    _ok(_record(repo, released))
    low = _stamp(repo, release=True, env={"BUILD_NUMBER": str(released)})
    assert low.returncode != 0 and "not greater than the last released code" in low.stderr
    high = _stamp(repo, release=True, env={"BUILD_NUMBER": str(released + 1)})
    assert f"export BUILD_NUMBER={released + 1}" in _ok(high)


def test_unpushed_local_tag_does_not_count_but_remote_tag_does(repo):
    released = _code_at("2026-10-24T10:00:00Z")
    _ok(_git(repo, "tag", f"android-vc-{released + 50}"))  # local only: ignored
    _ok(_stamp(repo, release=True))
    _ok(_git(repo, "push", "-q", "origin", f"refs/tags/android-vc-{released + 50}"))
    assert _stamp(repo, release=True).returncode != 0


def test_record_refuses_lower_code_and_off_main(repo):
    released = _code_at("2026-10-24T10:00:00Z")
    _ok(_record(repo, released))
    again = _record(repo, released)
    assert again.returncode != 0
    _ok(_git(repo, "checkout", "-q", "-b", "feature"))
    _commit_at(repo, "2026-10-24T13:00:00Z", "feature-1")
    off = _record(repo, _code_at("2026-10-24T13:00:00Z"))
    assert off.returncode != 0 and "not on origin/main" in off.stderr


# --- wrappers decide which builds are Play-bound ----------------------------


def test_dev_apk_from_branch_is_not_guarded(repo, tmp_path):
    _ok(_git(repo, "checkout", "-q", "-b", "feature"))
    _commit_at(repo, "2026-10-24T10:05:00Z", "feature-1")
    (repo / "dirty.txt").write_text("x")
    out = _wrapper(repo, tmp_path, "flutter_build_apk.sh", "--release", "--dart-define-from-file=flavors/dev.json")
    args = _ok(out).splitlines()
    assert f"--build-number={_code_at('2026-10-24T10:05:00Z')}" in args


@pytest.mark.parametrize(
    "name,args",
    [
        ("flutter_build_appbundle.sh", ["--release", "--dart-define-from-file=flavors/dev.json"]),
        ("flutter_build_appbundle.sh", ["--release"]),
        ("flutter_build_apk.sh", ["--release", "--dart-define-from-file=flavors/prod.json"]),
        ("flutter_build_apk.sh", ["--release", "--dart-define-from-file", "flavors/prod.json"]),
        ("flutter_build_apk.sh", ["--release", "--dart-define=APP_ENV=prod"]),
        ("flutter_build_apk.sh", ["--debug", "--dart-define-from-file=flavors/dev.json", "--dart-define=APP_ENV=prod"]),
    ],
)
def test_play_bound_builds_run_the_guard(repo, tmp_path, name, args):
    _ok(_git(repo, "checkout", "-q", "-b", "feature"))
    _commit_at(repo, "2026-10-24T10:05:00Z", "feature-1")
    out = _wrapper(repo, tmp_path, name, *args)
    assert out.returncode != 0
    assert "release guard" in out.stderr and "not on origin/main" in out.stderr
    assert "unbound variable" not in out.stderr  # stops at the guard, not by accident later
    assert "build" not in out.stdout.splitlines()


def test_dart_define_app_env_dev_overrides_prod_file(repo, tmp_path):
    _ok(_git(repo, "checkout", "-q", "-b", "feature"))
    _commit_at(repo, "2026-10-24T10:05:00Z", "feature-1")
    out = _wrapper(
        repo, tmp_path, "flutter_build_apk.sh", "--dart-define-from-file=flavors/prod.json", "--dart-define=APP_ENV=dev"
    )
    _ok(out)


def test_aab_from_clean_main_is_stamped(repo, tmp_path):
    out = _wrapper(repo, tmp_path, "flutter_build_appbundle.sh", "--release", "--dart-define-from-file=flavors/prod.json")
    args = _ok(out).splitlines()
    code = _code_at("2026-10-24T10:00:00Z")
    assert args[:2] == ["build", "appbundle"]
    assert f"--build-number={code}" in args and f"--dart-define=BUILD_NUMBER={code}" in args


def test_unreadable_flavor_file_fails_closed(repo, tmp_path):
    out = _wrapper(repo, tmp_path, "flutter_build_apk.sh", "--release", "--dart-define-from-file=flavors/missing.json")
    assert out.returncode != 0 and "cannot read --dart-define-from-file" in out.stderr
    assert "build" not in out.stdout.splitlines()


def test_split_per_abi_is_refused(repo, tmp_path):
    out = _wrapper(repo, tmp_path, "flutter_build_apk.sh", "--debug", "--split-per-abi")
    assert out.returncode != 0 and "--split-per-abi" in out.stderr
    assert "build" not in out.stdout.splitlines()
