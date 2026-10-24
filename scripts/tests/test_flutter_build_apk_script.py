"""apps/mobile/scripts/flutter_build_apk.sh: every APK build carries the build stamp."""

import os
import shutil
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[2]
_MOBILE = _REPO / "apps" / "mobile"
_WRAPPER = _MOBILE / "scripts" / "flutter_build_apk.sh"


def _run(tmp_path, *args, env_extra=None, copy_to=None):
    """Runs the wrapper with a fake `flutter` that prints its arguments."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    fake = bin_dir / "flutter"
    fake.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n')
    fake.chmod(0o755)
    wrapper = _WRAPPER
    if copy_to is not None:
        scripts = copy_to / "apps" / "mobile" / "scripts"
        scripts.mkdir(parents=True)
        for name in ("flutter_build_apk.sh", "build_stamp.sh"):
            shutil.copy2(_MOBILE / "scripts" / name, scripts / name)
        wrapper = scripts / "flutter_build_apk.sh"
    env = {k: v for k, v in os.environ.items() if k not in ("BUILD_NUMBER", "GITHUB_RUN_NUMBER", "REQUIRE_BUILD_STAMP")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(wrapper), *args],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )


def _head_sha():
    return subprocess.run(
        ["git", "-C", str(_REPO), "rev-parse", "--short", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def test_dev_build_gets_git_sha_and_build_number(tmp_path):
    result = _run(tmp_path, "--debug", "--dart-define-from-file=flavors/dev.json")
    assert result.returncode == 0, result.stderr
    args = result.stdout.splitlines()
    assert args[0] == "build" and args[1] == "apk"
    assert f"--dart-define=BUILD_GIT_SHA={_head_sha()}" in args
    number = next(a for a in args if a.startswith("--dart-define=BUILD_NUMBER="))
    assert number.split("=", 2)[2].isdigit()
    assert f"--build-number={number.split('=', 2)[2]}" in args
    assert args[-2:] == ["--debug", "--dart-define-from-file=flavors/dev.json"]


def test_explicit_build_number_wins(tmp_path):
    result = _run(tmp_path, "--release", env_extra={"BUILD_NUMBER": "4242"})
    assert result.returncode == 0, result.stderr
    assert "--build-number=4242" in result.stdout.splitlines()
    assert "--dart-define=BUILD_NUMBER=4242" in result.stdout.splitlines()


def test_dev_build_without_git_still_builds_with_unknown_stamp(tmp_path):
    result = _run(tmp_path, "--debug", copy_to=tmp_path / "nogit", env_extra={"GIT_CEILING_DIRECTORIES": str(tmp_path)})
    assert result.returncode == 0, result.stderr
    args = result.stdout.splitlines()
    assert "--dart-define=BUILD_GIT_SHA=unknown" in args
    assert not any(a.startswith("--build-number=") for a in args)


def test_prod_build_without_git_fails_loudly(tmp_path):
    result = _run(
        tmp_path,
        "--release",
        "--dart-define-from-file=flavors/prod.json",
        copy_to=tmp_path / "nogit",
        env_extra={"GIT_CEILING_DIRECTORIES": str(tmp_path)},
    )
    assert result.returncode != 0
    assert "BUILD_GIT_SHA is required" in result.stderr
    assert "build" not in result.stdout.splitlines()


def test_repo_apk_scripts_use_the_wrapper():
    scripts = [
        _MOBILE / "maestro" / "scripts" / "build-install.sh",
        _REPO / "scripts" / "ship_release_apk_to_drive.sh",
        _REPO / "scripts" / "ship_release_apk_x86_64_to_drive.sh",
    ]
    tracked = subprocess.run(
        ["git", "-C", str(_REPO), "ls-files", "*.sh"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    direct = [
        path
        for path in tracked
        if path != "apps/mobile/scripts/flutter_build_apk.sh"
        and "flutter build apk" in (_REPO / path).read_text()
    ]
    assert direct == [], f"build APKs via flutter_build_apk.sh: {direct}"
    for script in scripts:
        assert "flutter_build_apk.sh" in script.read_text(), script
